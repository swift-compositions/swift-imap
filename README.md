# swift-imap

Use this package when you want to read mail from an IMAP server: log in, list and examine mailboxes, search, and fetch messages. Start from `IMAP.Client`, given a transport. On Apple platforms use `IMAP.Network.Connection` from the `IMAP Network` product. Elsewhere, write your own `IMAP.Transport`. If you only need the IMAP4rev1 commands and responses as values, without a session, use swift-rfc-3501.

## Laws

- Commands are tagged `A1`, `A2` and so on, counting up for the life of the client.
- `IMAP.Client.search(_:)` and `IMAP.Client.fetch(_:_:)` always send the UID forms, so the numbers they take and return are UIDs.
- A client handles one exchange at a time. A command started while another is waiting for its reply throws `IMAP.Error.busy` at once. It doesn't queue.
- A command whose kind isn't in `IMAP.Client.allowed` is refused before any bytes are sent. By default every kind is allowed.
- With `IMAP.Client.readOnly` set, a fetch of a body section without peek is refused before any bytes are sent, because it would mark the message as seen.
- A value that can't be sent as an IMAP quoted string, such as text with non-ASCII characters, is refused before any bytes are sent.
- A completion other than OK throws, carrying the server's status, response code and text. This covers NO and BAD.
- An untagged BYE during any command except LOGOUT closes the connection and throws. `IMAP.Client.greeting()` accepts OK and PREAUTH and throws on BYE.
- A tagged reply with someone else's tag, or a continuation request, is a malformed response.
- A transport that returns no bytes means the server closed the connection.
- Replies may arrive split across reads at any point, including inside a literal.
- `IMAP.Client.logout()` ignores any error from the server and always closes the connection.
- `IMAP.Network.Connection` always uses TLS and connects to port 993 by default. Connecting, sending and receiving each give up after 60 seconds by cancelling the connection. A network that is waiting, for example because the host is unreachable, fails at once instead of retrying.
