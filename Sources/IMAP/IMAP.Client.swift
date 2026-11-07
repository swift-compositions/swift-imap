public import RFC_3501
import Byte

extension IMAP {

    public actor Client<Connection: IMAP.Transport> {

        let connection: Connection

        public let allowed: Set<RFC_3501.Command.Kind>

        var stream: RFC_3501.Response.Stream

        public let readOnly: Bool

        var busy = false

        var counter: Int

        public init(connection: Connection, allowed: Set<RFC_3501.Command.Kind> = Set(RFC_3501.Command.Kind.allCases), readOnly: Bool = false) {
            self.connection = connection
            self.allowed = allowed
            self.readOnly = readOnly
            self.stream = RFC_3501.Response.Stream()
            self.counter = 0
        }
    }
}

extension IMAP.Client {

    public func login(user: String, password: String) async throws(IMAP.Error) {
        _ = try await send(.login(user: user, password: password))
    }

    public func list(reference: String = "", pattern: String = "*") async throws(IMAP.Error) -> [RFC_3501.Response.List] {
        try await send(.list(reference: reference, pattern: pattern)).data.compactMap { data -> RFC_3501.Response.List? in
            switch data {
            case .list(let list): list
            default: nil
            }
        }
    }

    public func examine(_ mailbox: RFC_3501.Mailbox) async throws(IMAP.Error) -> IMAP.Reply {
        try await send(.examine(mailbox))
    }

    public func search(_ keys: [RFC_3501.Search.Key]) async throws(IMAP.Error) -> [UInt32] {
        try await send(.search(uid: true, keys)).data.flatMap { data -> [UInt32] in
            switch data {
            case .search(let numbers): numbers
            default: []
            }
        }
    }

    public func fetch(
        _ uids: RFC_3501.SequenceSet,
        _ attributes: [RFC_3501.Fetch.Attribute]
    ) async throws(IMAP.Error) -> [(sequence: UInt32, items: [RFC_3501.Fetch.Item])] {
        try await send(.fetch(uid: true, uids, attributes)).data.compactMap { data -> (sequence: UInt32, items: [RFC_3501.Fetch.Item])? in
            switch data {
            case .fetch(let sequence, let items): (sequence: sequence, items: items)
            default: nil
            }
        }
    }

    public func close() async {
        await connection.close()
    }

    public func logout() async {
        do throws(IMAP.Error) {
            _ = try await send(.logout)
        } catch {
        }
        await connection.close()
    }
}

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
