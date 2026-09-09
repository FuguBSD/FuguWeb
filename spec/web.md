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

Every generic part lives in the Fugu library. That library holds the name
pattern, the publication order, and the text of each generated file. It also
holds the armor decoder, the fingerprint, the Web Key Directory hash, and the
manifest parser. The renderer holds the wiring only.

### The description

- **WEB-KEYS-1** — The description must take at most one `keys` block. The block
  name must name a directory below the source directory, and must be one path
  segment.
- **WEB-KEYS-2** — The `keys` block must take an `org` word, which is the first
  field of every key name. A description without one is an error.
- **WEB-KEYS-3** — The `keys` block must take an optional `contact` value and an
  optional `expires` value. A description that names one and not the other is an
  error. The `expires` value must be a timestamp of RFC 3339.
- **WEB-KEYS-4** — The `keys` block must take an optional `url`, which is the
  published prefix of the directory. The value must be an absolute URL.
- **WEB-KEYS-5** — Each `key` block must name the stem of one key file in the
  directory. The extension of that file gives the type. The renderer must reject
  a stem that names no file, and one that names more than one.
- **WEB-KEYS-6** — Each `key` block must take a `status` of `current`, `next` or
  `retired`, and optional `since` and `until` values.
- **WEB-KEYS-7** — A `key` block of an OpenPGP key must take an optional `email`
  and an optional `fingerprint`. The renderer must reject either setting on a
  key of another type. The `email` value must be a local part and a domain, and
  the `fingerprint` value must be 40 hexadecimal characters.
- **WEB-KEYS-8** — The renderer must reject a setting that neither block
  defines, and a `key` block that a second block declares again.
- **WEB-KEYS-9** — The directory must hold a `SHA256` file and a `SHA256.sig`
  file. A directory without either one is an error.
- **WEB-KEYS-24** — The renderer must reject a symlink in the key directory. The
  build would publish the bytes of the target of the link.
- **WEB-KEYS-25** — The renderer must reject a `key` block that stands with no
  `keys` block.
- **WEB-KEYS-29** — The renderer must reject a `keys` name of `.`, of `..`, and
  of the staging directory of the build. None of the three names a directory
  that the build can publish.
- **WEB-KEYS-30** — The renderer must reject a `keys` name that the inventory
  already holds. The two would become one name in the output.
- **WEB-KEYS-31** — A signify key file must hold an untrusted comment line and a
  key body of 56 base64 characters. The body must decode to 42 bytes that start
  with `Ed`.
- **WEB-KEYS-32** — The human page must carry no footer fragment. A relative
  link of the fragment would resolve against the directory of that page.
- **WEB-KEYS-10** — A description with no `keys` block must build a site with no
  key directory.

### The build

- **WEB-KEYS-11** — The build must copy each key file, and the `SHA256` pair,
  byte for byte.
- **WEB-KEYS-12** — The build must generate `<dir>/KEYS` when the set holds an
  OpenPGP key, with every such key in publication order.
- **WEB-KEYS-13** — The build must generate `<dir>/index.html`. The page must
  name the serial, the purpose, the type, the status, the fingerprint and the
  dates of each key. It must link each key file.
- **WEB-KEYS-14** — The build must generate `.well-known/openpgpkey/hu/<hash>`
  for each email address that a key names, and must generate
  `.well-known/openpgpkey/policy` beside it. The file must hold the binary form
  of each OpenPGP key of that address, in publication order.
- **WEB-KEYS-28** — An address whose keys are all `retired` must serve no file.
  A reader of that file encrypts a message with the key that it holds.
- **WEB-KEYS-15** — The build must generate `.well-known/security.txt` when the
  `keys` block names a contact. The file must carry an `Encryption` field when
  the block names a `url`. The set must also hold a `current` OpenPGP key. The
  field must name the first such key of the publication order.
- **WEB-KEYS-16** — The inventory must name every path above, so the build and
  the checks read one list.
- **WEB-KEYS-17** — The build must sign nothing and must verify nothing.
- **WEB-KEYS-26** — The build must read each key file before it copies one. It
  must decode an armored key, and it must hold a signify key to its own shape. A
  build that refuses a key must copy no key at all. A build that fails later can
  leave the keys that it wrote, and the checks report the tree.

### The checks

- **WEB-KEYS-18** — Each key file must have a `key` block, and each block must
  have a file.
- **WEB-KEYS-19** — Each name in the directory must match the key name pattern.
- **WEB-KEYS-20** — Each purpose must hold exactly one `current` key.
- **WEB-KEYS-21** — `SHA256` must name every key file with the digest that the
  file has, and must name nothing else.
- **WEB-KEYS-22** — The declared fingerprint of an OpenPGP key must equal the
  fingerprint that its body gives.
- **WEB-KEYS-33** — `SHA256.sig` must hold a signify signature. The file must
  hold two lines. The first line must be an `untrusted comment: ` line. The
  second line must hold 100 base64 characters. Those characters must decode to
  74 bytes whose first two bytes spell `Ed`. The build verifies no signature: a
  site that verified its own manifest would prove nothing. It reads the shape
  because a file of another shape fails at every consumer install.
- **WEB-KEYS-23** — The checks must read the source directory, so the answer
  does not depend on a build having run.
- **WEB-KEYS-27** — The human page must take the checks of a page. It must take
  no reachability check, because a site links the key directory when it chooses
  to.

<a id="web-rotate"></a>

## The key rotation

`fuguweb build` and `fuguweb check` read the key directory, and
`fuguweb rotate-key` writes it. One command holds both steps of a rotation. The
reader and the writer share one implementation of the name pattern, the status
vocabulary and the manifest.

A consumer verifies a release against the copy of the public key that it holds.
A release that a new key signs therefore fails in each consumer that holds the
old copy. One rotation runs in two steps, and the trust order carries the gap. A
`mint` makes the next key, and a `promote` makes it current.

This command signs, and the build signs nothing (WEB-KEYS-17). It is the one
part of FuguWeb that needs `signify(1)`.

- **WEB-ROTATE-1** — `fuguweb rotate-key` must take a step of `mint` or
  `promote`, a purpose word, and the path of the private key file.
- **WEB-ROTATE-2** — A mint must take the next serial of the purpose, and
  generate a signify pair with no passphrase. It must write the public half into
  the key directory. It must write the private half to the named path, and that
  file must take no group mode and no other mode.
- **WEB-ROTATE-3** — A mint must give the new key the status `current` when the
  purpose holds no current key, and the status `next` otherwise.
- **WEB-ROTATE-4** — The command must read the status of each key from the
  description, and it must assume no status. A key file with no `key` block, and
  a `key` block with no file, must each fail the command.
- **WEB-ROTATE-5** — A mint must refuse a purpose that holds a `next` key
  already, and it must refuse before it generates a pair. A caller stores the
  private half of each mint in one place, so a second `next` key loses the
  private half of the first.
- **WEB-ROTATE-6** — The current key of the purpose must sign the manifest. A
  mint of a purpose that holds a current key must take the signer. It must never
  sign with the key that it generated. The first mint of a purpose is the one
  exception: that key is current, and it signs its own manifest.
- **WEB-ROTATE-7** — The command must verify the new signature against the
  published public key of the signer. A signature that the key does not verify
  must fail the command.
- **WEB-ROTATE-8** — The command must hold the old signature until a verified
  signature stands in its place. It must leave no directory that holds a
  manifest and no signature.
- **WEB-ROTATE-9** — A promote must make the `next` key of the purpose current.
  It must retire the key that was current with an `until` date.
- **WEB-ROTATE-10** — The command must write the description once in each run. A
  second write leaves the file half changed when it fails.
- **WEB-ROTATE-11** — The command must read the description back after it
  writes, and it must confirm the status of each key that it changed.
- **WEB-ROTATE-12** — The resulting key set must satisfy the status rules of
  `Fugu::KeyDir`, and the command must check the set before it returns.
- **WEB-ROTATE-13** — The command must print one `name=value` line for each fact
  that a caller needs. The facts are the file name, the stem, the serial, the
  status, and the retired name of a promote.
- **WEB-ROTATE-14** — The command must reach no network and must hold no token.
  The caller holds the credential.
- **WEB-ROTATE-16** — A mint must record the date of the run as `since` on the
  new `key` block. A promote must record it as `until` on the block of the key
  that it retires. Both dates must read in UTC.
- **WEB-ROTATE-17** — An absent `signify(1)` must fail the command with the exit
  code of a missing tool. A caller then tells it from a rotation that failed.
- **WEB-ROTATE-18** — A mint must refuse a `--secret` path that stands already,
  and one that names the signer. The private half of a key is the one thing that
  a rotation cannot make again. A caller holds each one in one place.
- **WEB-ROTATE-19** — Every key of one directory must hold one purpose. One
  manifest covers the directory and one key signs it. A second purpose leaves
  the current key of the first unable to verify the pair. A mint of another
  purpose must fail.
- **WEB-ROTATE-20** — A step must refuse a key set that breaks the status rules
  of `Fugu::KeyDir`, before it writes. A step over such a set could ask a
  retired key to sign. A directory with no key is the state of a site before its
  first mint, and it must stand.
- **WEB-ROTATE-21** — The key directory word must name one directory below the
  source directory, as WEB-KEYS-29 holds it.
- **WEB-ROTATE-15** — A description with no `keys` block must take one, with the
  organization word and the published prefix that the caller names. The block
  and the first key must arrive in one change, because a block that names an
  empty directory fails every build.

<a id="web-output"></a>

## The output directory

A build owns its output directory. It writes the site there, and it removes what
the site dropped. A second build over one directory therefore gives the same
tree as the first.

The output is one flat directory of files. The key directory is the one part
below it. A file there takes one of a bounded set of shapes, and rule
WEB-OUTPUT-10 states each one. A path of another shape belongs to whoever made
it, so the build keeps it and the clean refuses the tree.

- **WEB-OUTPUT-1** — The build must write a plain file. The file must sit at the
  top level of the output, or must take a shape of the key directory. Rule
  WEB-OUTPUT-10 states each shape, and rule WEB-OUTPUT-14 states the one
  exception.
- **WEB-OUTPUT-2** — The build must remove each file that the inventory does not
  name. Rule WEB-OUTPUT-1 states which file the build can remove.
- **WEB-OUTPUT-3** — The build must remove each empty directory that it owns. It
  owns a directory that the site holds a name below, and a directory of the key
  tree. It must keep the output directory itself.
- **WEB-OUTPUT-4** — The build must keep an entry that rule WEB-OUTPUT-1 does
  not let it write, and must report it. A directory that the description does
  not name holds the files of whoever made it.
- **WEB-OUTPUT-5** — The clean must remove a plain file of the top level. It
  must remove a file that the inventory names, and one that takes a shape of the
  key directory. It must remove a directory that holds a name of the site, and a
  directory of the key tree. Rule WEB-OUTPUT-14 states what it takes in the
  staging directory. It must refuse every other entry, and must name it.
- **WEB-OUTPUT-6** — The build and the clean must read one predicate. The build
  must never remove an entry that the clean refuses. The rule holds for a
  directory as it holds for a file.
- **WEB-OUTPUT-7** — The checks must report each entry of the output that the
  inventory does not name. The report must reach any depth, and an empty
  directory as well.
- **WEB-OUTPUT-8** — The build must refuse a symlink on a path that it writes,
  before it writes one file. An open follows a link, so a build would write the
  site outside its own directory.
- **WEB-OUTPUT-9** — The output path must take no trailing solidus. Each walk of
  the output cuts a relative path out of an absolute one.
- **WEB-OUTPUT-10** — A file below the top level must take a shape of the key
  directory. The shapes are these:

  - a generated name of the key directory: `SHA256`, `SHA256.sig`, `KEYS` or
    `index.html`;
  - a key file of the key directory, whose name matches rule WEB-KEYS-19;
  - `.well-known/security.txt`;
  - `.well-known/openpgpkey/policy`;
  - `.well-known/openpgpkey/hu/<hash>`, where the hash holds 32 characters of
    the z-base-32 alphabet.

  A stale key file needs this shape set. The inventory names what the site holds
  today, so it cannot answer for a key that the description dropped.

- **WEB-OUTPUT-11** — A `page` block name must be one path segment. A name with
  a solidus writes into the key directory tree, or into the staging directory,
  and the build would fail at the write.
- **WEB-OUTPUT-12** — A description with no `keys` block must own no shape of
  rule WEB-OUTPUT-10, and no directory of the key tree. A site of another maker
  holds `security.txt` too, and the clean must not delete that site.
- **WEB-OUTPUT-13** — The build and the clean must refuse an output directory
  that no build may own. They must refuse these targets: the root of the
  filesystem, the home directory, the project root, and any directory that holds
  the project. They must refuse the source directory, and each directory of it.
  The output directory of the description is the one exception, because the
  default output directory sits inside the default source directory. A
  description that names neither directory takes the two defaults.
- **WEB-OUTPUT-14** — The staging directory is the one part of the output that
  rule WEB-OUTPUT-1 does not reach. The build writes one flat directory of plain
  files there, and removes the whole directory at the end. The build must refuse
  a staging directory of another shape, and must not remove it. The clean must
  refuse the same one.
- **WEB-OUTPUT-15** — The clean must refuse a target that holds no stylesheet,
  when the description does not load. Every build writes the stylesheet, so a
  target without it is the output of no build. The rule is a second guard, and
  rule WEB-OUTPUT-13 is the first. A directory that holds a stylesheet of its
  own defeats this one alone.
