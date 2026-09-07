# The site renderer

FuguWeb renders one static site from the documentation of a Perl project. The
renderer reads `.fuguwebrc` at the project root, runs `mandoc`, `lowdown`, and
`pod2man`, and wraps each result in one shared chrome. The output is plain HTML
and one stylesheet: no templating language and no JavaScript.

The code predates the specification, so this document holds the units of the
areas that a plan has changed and no more. Each future plan adds the units of
the area that it changes. The conventions of [index.md](index.md) apply.

<a id="web-keys"></a>

## The key directory

An organization publishes its public keys under one prefix, so a consumer
install can fetch a key and verify a release with it. A site describes that
directory in `.fuguwebrc`, and the renderer publishes it.

Every generic part lives in the Fugu library: the name pattern, the publication
order, the text of the `KEYS` file and of `security.txt`, the armor decoder, the
fingerprint, the Web Key Directory hash, and the manifest parser. The renderer
holds the wiring only.

### The description

- **WEB-KEYS-1** — The description must take at most one `keys` block. The block
  name must name a directory below the source directory, and must be one path
  segment.
- **WEB-KEYS-2** — The `keys` block must take an `org` word, which is the first
  field of every key name, and must reject a description without one.
- **WEB-KEYS-3** — The `keys` block must take an optional `contact` value and an
  optional `expires` value, and must reject a description that names one and not
  the other.
- **WEB-KEYS-4** — The `keys` block must take an optional `url`, which is the
  published prefix of the directory, and must reject a value that is not an
  absolute URL.
- **WEB-KEYS-5** — Each `key` block must name the stem of one key file in the
  directory. The renderer must read the type from the extension of that file,
  and must reject a stem that names no file or more than one.
- **WEB-KEYS-6** — Each `key` block must take a `status` of `current`, `next` or
  `retired`, and optional `since` and `until` values.
- **WEB-KEYS-7** — A `key` block of an OpenPGP key must take an optional `email`
  and an optional `fingerprint`. The renderer must reject either setting on a
  key of another type.
- **WEB-KEYS-8** — The renderer must reject a setting that neither block
  defines, and a `key` block that a second block declares again.
- **WEB-KEYS-9** — The directory must hold a `SHA256` file and a `SHA256.sig`
  file, and the renderer must reject a directory without either one.
- **WEB-KEYS-10** — A description with no `keys` block must build a site with no
  key directory.

### The build

- **WEB-KEYS-11** — The build must copy each key file, and the `SHA256` pair,
  byte for byte.
- **WEB-KEYS-12** — The build must generate `<dir>/KEYS` when the set holds an
  OpenPGP key, with every such key in publication order.
- **WEB-KEYS-13** — The build must generate `<dir>/index.html`, which names the
  serial, the purpose, the type, the status, the fingerprint and the dates of
  each key, and links each key file.
- **WEB-KEYS-14** — The build must generate `.well-known/openpgpkey/hu/<hash>`,
  in the binary form, for each OpenPGP key that names an email, and must
  generate `.well-known/openpgpkey/policy` beside it.
- **WEB-KEYS-15** — The build must generate `.well-known/security.txt` when the
  `keys` block names a contact. The file must carry an `Encryption` field that
  names the current OpenPGP key when the block names a `url`.
- **WEB-KEYS-16** — The inventory must name every path above, so the build and
  the checks read one list.
- **WEB-KEYS-17** — The build must sign nothing and must verify nothing.

### The checks

- **WEB-KEYS-18** — Each key file must have a `key` block, and each block must
  have a file.
- **WEB-KEYS-19** — Each name in the directory must match the key name pattern.
- **WEB-KEYS-20** — Each purpose must hold exactly one `current` key.
- **WEB-KEYS-21** — `SHA256` must name every key file with the digest that the
  file has, and must name nothing else.
- **WEB-KEYS-22** — The declared fingerprint of an OpenPGP key must equal the
  fingerprint that its body gives.
- **WEB-KEYS-23** — The checks must read the source directory, so the answer
  does not depend on a build having run.
