#if canImport(Network)
    public import IMAP
    import Network

    extension IMAP.Network {

        public struct Connection: Sendable {

            let connection: NWConnection
        }
    }
#endif
