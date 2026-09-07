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

| Unit                        | State | Done by | Note                                                                 |
| --------------------------- | ----- | ------- | -------------------------------------------------------------------- |
| [WEB-KEYS](web.md#web-keys) | done  | —       | [Keys.pm](../lib/App/FuguWeb/Keys.pm), [keys.t](../t/fuguweb/keys.t) |

## Retired IDs

| ID  |
| --- |
