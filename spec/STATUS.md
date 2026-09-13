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

| Unit                              | State | Done by | Note                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| --------------------------------- | ----- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [WEB-KEYS](web.md#web-keys)       | done  | —       | [Config.pm](../lib/App/FuguWeb/Config.pm) reads each `keys` block, and [Keys.pm](../lib/App/FuguWeb/Keys.pm) publishes one directory at a time. `site_generated` gathers the well-known tree of the site. [keys.t](../t/fuguweb/keys.t)                                                                                                                                                                                                                                                           |
| [WEB-OUTPUT](web.md#web-output)   | done  | —       | [Site.pm](../lib/App/FuguWeb/Site.pm), [Config.pm](../lib/App/FuguWeb/Config.pm), [keys.t](../t/fuguweb/keys.t)                                                                                                                                                                                                                                                                                                                                                                                   |
| [WEB-ROTATE](web.md#web-rotate)   | done  | —       | [Rotate.pm](../lib/App/FuguWeb/Rotate.pm) writes one key directory, and `--dir` of [CLI.pm](../lib/App/FuguWeb/CLI.pm) selects it. [rotate.t](../t/fuguweb/rotate.t)                                                                                                                                                                                                                                                                                                                              |
| [WEB-TRUST](web.md#web-trust)     | done  | —       | [Rotate.pm](../lib/App/FuguWeb/Rotate.pm), [Keys.pm](../lib/App/FuguWeb/Keys.pm), [rotate.t](../t/fuguweb/rotate.t), [keys.t](../t/fuguweb/keys.t)                                                                                                                                                                                                                                                                                                                                                |
| [WEB-OPENPGP](web.md#web-openpgp) | done  | —       | `_generate_openpgp` of [Rotate.pm](../lib/App/FuguWeb/Rotate.pm) mints the key with its encryption subkey, `_openpgp_settings` writes the `email` and the `fingerprint` into its block, and `_bind` signs its binding. `_expiry_problems` of [Keys.pm](../lib/App/FuguWeb/Keys.pm) reports an expiry, and `_binding_verified` reads the binding. [rotate.t](../t/fuguweb/rotate.t), [keys.t](../t/fuguweb/keys.t)                                                                                 |
| [WEB-X509](web.md#web-x509)       | done  | —       | `_add` of [Rotate.pm](../lib/App/FuguWeb/Rotate.pm) imports a certificate and writes its `fingerprint`, `_bind` signs the `.p7s` binding with `Fugu::X509`, and `key_set` of [Keys.pm](../lib/App/FuguWeb/Keys.pm) decodes the `.pem` file. `_describe` names the subject and the validity dates on the human page, `_expiry_problems` reports a certificate that is not valid today, and `_binding_verified` reads the binding. [rotate.t](../t/fuguweb/rotate.t), [keys.t](../t/fuguweb/keys.t) |
| [WEB-ACTIONS](web.md#web-actions) | done  | —       | [keys-rotate.yml](../.github/workflows/keys-rotate.yml) runs one step of one purpose, and it composes [keys-slot](../actions/keys-slot/action.yml) and [keys-store](../actions/keys-store/action.yml). Each `uses:` line pins its action to a commit. [keys-rotate.t](../t/ci/keys-rotate.t) holds the order, each guard, and each pin.                                                                                                                                                           |

## Retired IDs

| ID  |
| --- |
