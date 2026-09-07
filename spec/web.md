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
  the other. The `expires` value must be a timestamp of RFC 3339.
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
  key of another type. The `email` value must be a local part and a domain, and
  the `fingerprint` value must be 40 hexadecimal characters.
- **WEB-KEYS-8** — The renderer must reject a setting that neither block
  defines, and a `key` block that a second block declares again.
- **WEB-KEYS-9** — The directory must hold a `SHA256` file and a `SHA256.sig`
  file, and the renderer must reject a directory without either one.
- **WEB-KEYS-24** — The renderer must reject a symlink in the key directory. The
  build would publish the bytes of the target of the link.
- **WEB-KEYS-25** — The renderer must reject a `key` block that stands with no
  `keys` block.
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
- **WEB-KEYS-14** — The build must generate `.well-known/openpgpkey/hu/<hash>`
  for each email address that a key names, and must generate
  `.well-known/openpgpkey/policy` beside it. The file must hold the binary form
  of each OpenPGP key of that address, in publication order.
- **WEB-KEYS-15** — The build must generate `.well-known/security.txt` when the
  `keys` block names a contact. The file must carry an `Encryption` field when
  the block names a `url`. The field must name the first `current` OpenPGP key
  of the publication order.
- **WEB-KEYS-16** — The inventory must name every path above, so the build and
  the checks read one list.
- **WEB-KEYS-17** — The build must sign nothing and must verify nothing.
- **WEB-KEYS-26** — The build must hold each armored key to the guards of the
  key directory module before it copies one file. A failed build must leave no
  key in the output.

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
- **WEB-KEYS-27** — The human page must take the checks of a page. It must take
  no reachability check, because a site links the key directory when it chooses
  to.

<a id="web-output"></a>

## The output directory

A build owns its output directory. It writes the site there, and it removes what
the site dropped, so a second build over one directory gives the same tree as
the first.

The output is one flat directory of files. The key directory is the one part
below it, so the build writes into two prefixes there: the directory that the
`keys` block names, and `.well-known`.

- **WEB-OUTPUT-1** — The build must write a plain file, at the top level of the
  output or below a prefix of the key directory, and must write nothing else.
- **WEB-OUTPUT-2** — The build must remove each file of the output that the
  inventory does not name and that rule WEB-OUTPUT-1 lets it write.
- **WEB-OUTPUT-3** — The build must remove each directory of a key directory
  prefix that holds nothing. It must keep the output directory itself.
- **WEB-OUTPUT-4** — The build must keep a file that rule WEB-OUTPUT-1 does not
  let it write, and must report it. A directory that the description does not
  name holds the files of whoever made it.
- **WEB-OUTPUT-5** — The clean must remove the output directory. It must refuse
  a target that holds an entry which rule WEB-OUTPUT-1 does not let a build
  write, and it must name that entry.
- **WEB-OUTPUT-6** — The prune and the clean must read one ownership rule, so
  the build can never remove what the clean refuses.
- **WEB-OUTPUT-7** — The checks must report each entry of the output that the
  inventory does not name, at any depth, and an empty directory as well.
- **WEB-OUTPUT-8** — The build and the clean must refuse a symlink in the
  output.
