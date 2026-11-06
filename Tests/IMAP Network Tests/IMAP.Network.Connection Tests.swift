#if canImport(Network)
    import IMAP
    import IMAP_Network
    import RFC_3986
    import Testing

    extension IMAP.Network.Connection {
        @Suite struct Test {
            @Suite struct `Edge Case` {}
        }
    }

    extension IMAP.Network.Connection.Test.`Edge Case` {

        @Test(.timeLimit(.minutes(1)))
        func `a refused loopback connection is a transport error`() async throws {
            let host = try RFC_3986.URI.Host("127.0.0.1")
            await #expect(throws: IMAP.Error.self) {
                _ = try await IMAP.Network.Connection.connect(host: host, port: 1)
            }
        }
    }
#endif
