# swift-imap

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

An IMAP4rev1 client for reading mail, composed from swift-rfc-3501 and swift-rfc-3501-coder.

- `IMAP.Client` is an actor over any `IMAP.Transport`. It tags commands, assembles responses (literals included) and turns a NO or BAD completion into an error. A client can be restricted to a set of command kinds; a command outside the set is refused before anything is sent.
- `IMAP Network` provides `IMAP.Network.Connection`, a TLS transport on Network.framework, on Apple platforms. A transport for Linux is planned.

The protocol types model reading commands only (CAPABILITY, NOOP, LOGOUT, LOGIN, LIST, EXAMINE, UID SEARCH, UID FETCH); nothing that changes a mailbox can be expressed.

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
