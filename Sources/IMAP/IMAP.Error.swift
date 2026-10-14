public import RFC_3501

extension IMAP {

    public enum Error: Swift.Error, Sendable, Equatable {

        case refused(RFC_3501.Command.Kind)

        case unquotable(String)

        case transport(String)

        case busy

        case closed

        case malformed(String)

        case failed(RFC_3501.Response.Condition)
    }
}
