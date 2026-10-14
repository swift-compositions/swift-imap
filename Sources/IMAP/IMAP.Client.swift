public import RFC_3501
import RFC_3501_Coder

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
