# The site renderer

FuguWeb renders one static site from the documentation of a Perl project. The
renderer reads `.fuguwebrc` at the project root, runs `mandoc`, `lowdown`, and
`pod2man`, and wraps each result in one shared chrome. The output is plain HTML
and one stylesheet: no templating language and no JavaScript.

This document holds no unit yet. The code predates the specification, and each
future plan adds the units of the area that it changes. The conventions of
[index.md](index.md) apply.
