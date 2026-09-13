# Implementation register

This register is the one record of implementation state. One row exists for each
unit of the specification. The [conventions](index.md#conventions) define the
unit IDs.

## States

| State   | Meaning                                                              |
| ------- | -------------------------------------------------------------------- |
| open    | No code implements the unit.                                         |
| partial | Code implements a part of the unit. The note names each absent part. |
| done    | Code implements the full unit. The note links the code or the tests. |
| n-a     | No code can implement the unit. It exists for citation only.         |

## Units

| Unit                              | State   | Done by | Note                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| --------------------------------- | ------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [WEB-KEYS](web.md#web-keys)       | done    | —       | [Keys.pm](../lib/App/FuguWeb/Keys.pm), [keys.t](../t/fuguweb/keys.t)                                                                                                                                                                                                                                                                                                                                                                                       |
| [WEB-OUTPUT](web.md#web-output)   | done    | —       | [Site.pm](../lib/App/FuguWeb/Site.pm), [Config.pm](../lib/App/FuguWeb/Config.pm), [keys.t](../t/fuguweb/keys.t)                                                                                                                                                                                                                                                                                                                                            |
| [WEB-ROTATE](web.md#web-rotate)   | done    | —       | [Rotate.pm](../lib/App/FuguWeb/Rotate.pm), [CLI.pm](../lib/App/FuguWeb/CLI.pm), [rotate.t](../t/fuguweb/rotate.t)                                                                                                                                                                                                                                                                                                                                          |
| [WEB-TRUST](web.md#web-trust)     | done    | —       | [Rotate.pm](../lib/App/FuguWeb/Rotate.pm), [Keys.pm](../lib/App/FuguWeb/Keys.pm), [rotate.t](../t/fuguweb/rotate.t), [keys.t](../t/fuguweb/keys.t)                                                                                                                                                                                                                                                                                                         |
| [WEB-OPENPGP](web.md#web-openpgp) | partial | —       | [Rotate.pm](../lib/App/FuguWeb/Rotate.pm) signs a binding of this type, and [Keys.pm](../lib/App/FuguWeb/Keys.pm) verifies one. The mint of WEB-OPENPGP-1 to WEB-OPENPGP-3 and the expiry check of WEB-OPENPGP-4 are absent.                                                                                                                                                                                                                               |
| [WEB-X509](web.md#web-x509)       | partial | —       | `_bind` of [Rotate.pm](../lib/App/FuguWeb/Rotate.pm) signs a binding of this type, per [rotate.t](../t/fuguweb/rotate.t), and [Keys.pm](../lib/App/FuguWeb/Keys.pm) holds its verifier. No verb completes a step with a `.pem` key today. `key_set` reads such a key as a signify key, and `_accept` then rejects the directory. The import of WEB-X509-2, each check of the certificate, and the subject and the validity dates of WEB-X509-5 are absent. |
| [WEB-ACTIONS](web.md#web-actions) | open    | —       | Nothing implements it.                                                                                                                                                                                                                                                                                                                                                                                                                                     |

## Retired IDs

| ID  |
| --- |
