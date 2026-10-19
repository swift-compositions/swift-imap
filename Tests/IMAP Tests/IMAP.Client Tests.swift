import Byte
import IMAP
import RFC_3501
import Synchronization
import Testing

@Suite
struct `IMAP.Client Tests` {

    final class Script: IMAP.Transport {

        let state: Mutex<(replies: [[Byte]], sent: [String])>

        init(_ replies: [String]) {
            state = Mutex((replies: replies.map { [Byte](utf8: $0) }, sent: []))
        }

        var sent: [String] { state.withLock { $0.sent } }

        func send(_ bytes: [Byte]) async throws(IMAP.Error) {
            state.withLock { $0.sent.append(String(decoding: bytes.map(\.bitPattern), as: UTF8.self)) }
        }

        func receive() async throws(IMAP.Error) -> [Byte] {
            state.withLock { $0.replies.isEmpty ? [] : $0.replies.removeFirst() }
        }

        func close() async {}
    }

    @Suite
    struct Unit {

        @Test
        func `a session greets, logs in, searches and fetches`() async throws {
            let script = Script([
                "* OK [CAPABILITY IMAP4rev1] ready\r\n",
                "A1 OK logged in\r\n",
                "* 3 EXISTS\r\n* OK [UIDVALIDITY 7] ok\r\nA2 OK [READ-ONLY] done\r\n",
                "* SEARCH 4 9\r\nA3 OK",
                " done\r\n",
                "* 1 FETCH (UID 4 BODY[] {7}\r\nSubject",
                ")\r\nA4 OK done\r\n",
            ])
            let client = IMAP.Client(connection: script)

            #expect(try await client.greeting().status == .ok)
            try await client.login(user: "me@example.com", password: "abcd-efgh")
            #expect(try await client.examine(.inbox).completion.code == .readOnly)
            #expect(try await client.search([.from("example.nl")]) == [4, 9])
            let fetched = try await client.fetch(RFC_3501.SequenceSet([4]), [.uid, .body(.whole, peek: true)])

            #expect(fetched.count == 1)
            #expect(fetched.first?.items == [.uid(4), .body(.whole, origin: nil, data: [Byte](utf8: "Subject"))])
            #expect(
                script.sent == [
                    "A1 LOGIN me@example.com abcd-efgh\r\n",
                    "A2 EXAMINE INBOX\r\n",
                    "A3 UID SEARCH FROM example.nl\r\n",
                    "A4 UID FETCH 4 (UID BODY.PEEK[])\r\n",
                ]
            )
        }

        @Test
        func `a refused command never reaches the transport`() async {
            let script = Script([])
            let client = IMAP.Client(connection: script, allowed: [.search])

            await #expect(throws: IMAP.Error.refused(.login)) {
                try await client.login(user: "u", password: "p")
            }
            #expect(script.sent.isEmpty)
        }

        @Test
        func `read only rejects non peek fetch before any bytes are sent`() async {
            let script = Script([])
            let client = IMAP.Client(connection: script, readOnly: true)
            await #expect(throws: IMAP.Error.refused(.fetch)) {
                _ = try await client.fetch(RFC_3501.SequenceSet([1]), [.body(.whole, peek: false)])
            }
            #expect(script.sent.isEmpty)
        }

        @Test
        func `server shutdown aborts an exchange`() async {
            let client = IMAP.Client(connection: Script(["* BYE closing\r\n"]))
            await #expect(throws: IMAP.Error.failed(.init(status: .bye, code: nil, text: "closing"))) {
                _ = try await client.send(.noop)
            }
        }

        @Test
        func `a NO completion is an error`() async {
            let client = IMAP.Client(connection: Script(["A1 NO [AUTHENTICATIONFAILED] wrong\r\n"]))

            await #expect(throws: IMAP.Error.failed(.init(status: .no, code: .other("AUTHENTICATIONFAILED"), text: "wrong"))) {
                try await client.login(user: "u", password: "p")
            }
        }
    }

    @Suite
    struct `Edge Case` {

        @Test
        func `a closed connection is an error`() async {
            let client = IMAP.Client(connection: Script(["* OK ready\r\n"]))

            await #expect(throws: IMAP.Error.closed) {
                _ = try await client.greeting()
                try await client.login(user: "u", password: "p")
            }
        }

        @Test
        func `an unquotable value is refused before sending`() async {
            let script = Script([])
            let client = IMAP.Client(connection: script)

            await #expect(throws: IMAP.Error.unquotable("café")) {
                _ = try await client.search([.subject("café")])
            }
            #expect(script.sent.isEmpty)
        }

        @Test
        func `a BYE greeting is an error`() async {
            await #expect(throws: IMAP.Error.failed(.init(status: .bye, code: nil, text: "busy"))) {
                _ = try await IMAP.Client(connection: Script(["* BYE busy\r\n"])).greeting()
            }
        }
    }
}
