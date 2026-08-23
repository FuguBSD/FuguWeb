# Implementation register

This register is the one record of implementation state. One row exists for each
unit of the specification. The [conventions](index.md#conventions) define the
unit IDs. The specification holds no unit yet, so the table holds no row.

## States

| State   | Meaning                                                              |
| ------- | -------------------------------------------------------------------- |
| open    | No code implements the unit.                                         |
| partial | Code implements a part of the unit. The note names each absent part. |
| done    | Code implements the full unit. The note links the code or the tests. |
| n-a     | No code can implement the unit. It exists for citation only.         |

## Units

| Unit | State | Done by | Note |
| ---- | ----- | ------- | ---- |

## Retired IDs

| ID  |
| --- |
