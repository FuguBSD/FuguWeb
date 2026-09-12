# Decisions

This document holds the decisions that govern FuguWeb. A plan must not go
against a decision. To change a decision, propose the change and get human
approval first.

| ID   | Decision                                                                                                                     | Rationale                                                                                                                                                                                                                             |
| ---- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D-01 | The site output is plain HTML and one stylesheet: no templating language and no JavaScript.                                  | The output stays auditable, and every renderer stays replaceable.                                                                                                                                                                     |
| D-02 | The signify key of the `root` purpose is the root of trust of a key directory. Every other key of the directory binds to it. | One line holds a signify key, so a consumer pins it with one line, and one small tool verifies it on every platform. An OpenPGP key and an X.509 certificate each bring an issuer or a web of trust that a consumer must learn first. |
| D-03 | The key verbs read and write each private key as a file, and hold no secret store.                                           | A workflow writes a secret into a file and reads one back. The verbs then serve GitHub Actions, a vault, and a shell the same way.                                                                                                    |
