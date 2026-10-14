public import RFC_3501

extension IMAP {

    public struct Reply: Sendable, Hashable {

        public let data: [RFC_3501.Response.Data]

        public let completion: RFC_3501.Response.Condition

        public init(data: [RFC_3501.Response.Data], completion: RFC_3501.Response.Condition) {
            self.data = data
            self.completion = completion
        }
    }
}
