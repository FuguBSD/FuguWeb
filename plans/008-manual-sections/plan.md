# 008 — The section 7 manual

A `manuals` group drops a section 7 manual. The section list of
[Config.pm](../../lib/App/FuguWeb/Config.pm) holds `1`, `3p`, `5` and `8`, so
the group takes no `.7` file. A group with no manual adds nothing to the index,
so the build reports no error. FuguSeed keeps its offline procedure in
`man/fuguseed/fuguseed.7`, and the site of that project loses the page.

Implements: WEB-MANUALS.

## Steps

1. Add `7` to the section list of [Config.pm](../../lib/App/FuguWeb/Config.pm),
   between `5` and `8`.
2. Name section 7 in the comment above the list, and in the comment of
   `_mdoc_manuals`.
3. Name section 7 in [Config.pod](../../lib/App/FuguWeb/Config.pod), in the
   description of a `manuals` group.
4. Name section 7 in [fuguweb.1](../../man/fuguweb/fuguweb.1), in the
   description of a `manuals` group.
5. Add a section 7 fixture to [index.t](../../t/fuguweb/index.t), and add the
   file to each order assertion of that test.
6. Move the register row of WEB-MANUALS to `done` in
   [STATUS.md](../../spec/STATUS.md), and delete this plan directory.

## Status

- The six steps land now, in one change, in the order above.
- No step waits. The change needs no other plan, and no sibling repository.
