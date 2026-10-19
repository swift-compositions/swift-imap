import Byte
public import RFC_3501
import RFC_3501_Coder

extension IMAP.Client {

    public func greeting() async throws(IMAP.Error) -> RFC_3501.Response.Condition {
        guard !busy else { throw .busy }
        busy = true
        defer { busy = false }
        switch try await response() {
        case .untagged(.condition(let condition)) where condition.status == .ok || condition.status == .preauth:
            return condition
        case .untagged(.condition(let condition)):
            throw .failed(condition)
        default:
            throw .malformed("expected a greeting")
        }
    }

    public func send(_ command: RFC_3501.Command) async throws(IMAP.Error) -> IMAP.Reply {
        guard allowed.contains(command.kind) else { throw .refused(command.kind) }
        if readOnly, case .fetch(_, _, let attributes) = command,
            attributes.contains(where: { if case .body(_, peek: false) = $0 { true } else { false } })
        {
            throw .refused(.fetch)
        }
        guard !busy else { throw .busy }
        busy = true
        defer { busy = false }
        counter += 1
        let tag = RFC_3501.Tag(rawValue: "A\(counter)")
        let line: [Byte]
        do throws(RFC_3501.Command.Error) {
            line = try [Byte](command, tag: tag)
        } catch {
            switch error {
            case .unquotable(let value): throw .unquotable(value)
            }
        }
        try await connection.send(line)
        var data: [RFC_3501.Response.Data] = []
        while true {
            switch try await response() {
            case .untagged(.condition(let condition)) where condition.status == .bye && command.kind != .logout:
                await connection.close()
                throw .failed(condition)
            case .untagged(let item):
                data.append(item)
            case .tagged(let received, let condition) where received == tag:
                guard condition.status == .ok else { throw .failed(condition) }
                return IMAP.Reply(data: data, completion: condition)
            case .tagged, .continuation:
                throw .malformed("unexpected response while waiting for \(tag.rawValue)")
            }
        }
    }

    func response() async throws(IMAP.Error) -> RFC_3501.Response {
        while true {
            if let bytes = stream.next() {
                do throws(RFC_3501.Response.Error) {
                    return try RFC_3501.Response(binary: bytes)
                } catch {
                    switch error {
                    case .malformed(let reason): throw .malformed(reason)
                    }
                }
            }
            let chunk = try await connection.receive()
            guard !chunk.isEmpty else { throw .closed }
            stream.append(chunk)
        }
    }
}
