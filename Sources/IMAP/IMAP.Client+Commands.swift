public import RFC_3501

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
