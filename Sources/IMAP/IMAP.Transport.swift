public import Byte

extension IMAP {

    public protocol Transport: Sendable {

        func send(_ bytes: [Byte]) async throws(IMAP.Error)

        func receive() async throws(IMAP.Error) -> [Byte]

        func close() async
    }
}
