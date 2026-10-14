#if canImport(Network)
  import IMAP
  import IMAP_Network
  import Testing

  extension IMAP.Network.Connection {
    @Suite struct Test {
      @Suite struct `Edge Case` {}
    }
  }

  extension IMAP.Network.Connection.Test.`Edge Case` {

    @Test(.timeLimit(.minutes(1)))
    func `a refused loopback connection is a transport error`() async {
      await #expect(throws: IMAP.Error.self) {
        _ = try await IMAP.Network.Connection.connect(host: "127.0.0.1", port: 1)
      }
    }
  }
#endif
