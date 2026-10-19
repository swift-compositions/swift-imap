#if canImport(Network)
    public import Byte
    public import IMAP
    import Dispatch
    import Foundation
    import Network
    import Synchronization

    extension IMAP.Network.Connection: IMAP.Transport {

        public static func connect(host: String, port: UInt16 = 993) async throws(IMAP.Error) -> IMAP.Network.Connection {
            guard let endpoint = NWEndpoint.Port(rawValue: port) else { throw .transport("invalid port \(port)") }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: endpoint, using: .tls)
            let deadline = DispatchWorkItem { connection.cancel() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: deadline)
            defer { deadline.cancel() }
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, IMAP.Error>, Never>) in
                let resumed = Mutex(false)
                connection.stateUpdateHandler = { state in
                    let outcome: Result<Void, IMAP.Error>? =
                        switch state {
                        case .ready: .success(())
                        case .failed(let error), .waiting(let error): .failure(.transport("\(error)"))
                        case .cancelled: .failure(.closed)
                        default: nil
                        }
                    guard let outcome,
                        resumed.withLock({ value in
                            defer { value = true }
                            return !value
                        })
                    else { return }
                    continuation.resume(returning: outcome)
                }
                connection.start(queue: DispatchQueue(label: "imap.network.connection"))
            }
            switch result {
            case .success:
                return IMAP.Network.Connection(connection: connection)
            case .failure(let error):
                connection.cancel()
                throw error
            }
        }

        public func send(_ bytes: [Byte]) async throws(IMAP.Error) {
            let deadline = DispatchWorkItem { connection.cancel() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: deadline)
            defer { deadline.cancel() }
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, IMAP.Error>, Never>) in
                connection.send(
                    content: Data(bytes.map(\.bitPattern)),
                    completion: .contentProcessed { error in
                        continuation.resume(returning: error.map { .failure(.transport("\($0)")) } ?? .success(()))
                    }
                )
            }
            try result.get()
        }

        public func receive() async throws(IMAP.Error) -> [Byte] {
            let deadline = DispatchWorkItem { connection.cancel() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: deadline)
            defer { deadline.cancel() }
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[Byte], IMAP.Error>, Never>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { content, _, _, error in
                    continuation.resume(
                        returning: error.map { .failure(.transport("\($0)")) }
                            ?? .success((content ?? Data()).map(Byte.init(bitPattern:)))
                    )
                }
            }
            return try result.get()
        }

        public func close() async {
            connection.cancel()
        }
    }
#endif
