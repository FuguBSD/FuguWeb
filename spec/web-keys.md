# The keys

This document holds the key directory and the root of trust. [web.md](web.md)
holds the model of the site, and the conventions of [index.md](index.md) apply.

<a id="web-keys"></a>

## The key directory

An organization publishes its public keys under one prefix, so a consumer
install can fetch a key and verify a release with it. A site describes each such
directory in `.fuguwebrc`, and the renderer publishes it. A publisher that keeps
two trust domains keeps two directories in one site, and each directory holds
its own root of trust, per D-02.

Every generic part lives in the Fugu library. That library holds the name
pattern, the publication order, and the text of each generated file. It also
holds the armor decoder, the fingerprint, the Web Key Directory hash, and the
manifest parser. The renderer holds the wiring only.

### The description

- **WEB-KEYS-1** — The description must take any number of `keys` blocks. Each
  block name must name a directory below the source directory, and must be one
  path segment. Two blocks must not name one directory.
- **WEB-KEYS-2** — The `keys` block must take an `org` word, which is the first
  field of every key name. A description without one is an error. Two blocks
  must not name one `org` word. The serial of a purpose counts inside one
  directory. A mint of the second block would write a name that the first block
  publishes.
- **WEB-KEYS-3** — The `keys` block must take an optional `contact` value and an
  optional `expires` value. A description that names one and not the other is an
  error. The `expires` value must be a timestamp of RFC 3339. One block alone
  must take the two, because the site publishes one `security.txt`. A second
  block that names either one is an error.
- **WEB-KEYS-4** — The `keys` block must take an optional `url`, which is the
  published prefix of the directory. The value must be an absolute URL.
- **WEB-KEYS-5** — Each `key` block must name the stem of one key file of one
  key directory. The directory that holds the file gives the directory of the
  block. The extension of that file gives the type: `.pub` names a signify key,
  `.asc` an armored OpenPGP key, and `.pem` an X.509 certificate. The renderer
  must reject a stem that names no file, and one that names more than one.
- **WEB-KEYS-6** — Each `key` block must take a `status` of `current`, `next` or
  `retired`, and optional `since` and `until` values.
- **WEB-KEYS-7** — A `key` block of an OpenPGP key must take an optional `email`
  and an optional `fingerprint`. A block of a certificate must take an optional
  `fingerprint`. The renderer must reject an `email` on a certificate, and it
  must reject both settings on a signify key. The `email` value must be a local
  part and a domain. The `fingerprint` of an OpenPGP key must be 40 hexadecimal
  characters, and the one of a certificate must be 64, per WEB-X509-4.
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
  already holds, and one that a second `keys` block holds. Two such names would
  become one name in the output.
- **WEB-KEYS-34** — The renderer must reject a `keys` name that is the path of
  the tree of a declared language. Such a name would take the place of that
  tree, per WEB-LANGUAGE-5.
- **WEB-KEYS-31** — A signify key file must hold an untrusted comment line and a
  key body of 56 base64 characters. The body must decode to 42 bytes that start
  with `Ed`.
- **WEB-KEYS-32** — The human page must carry no footer fragment. A relative
  link of the fragment would resolve against the directory of that page.
- **WEB-KEYS-10** — A description with no `keys` block must build a site with no
  key directory.

### The build

- **WEB-KEYS-11** — The build must copy each key file, each binding file, and
  the `SHA256` pair, byte for byte.
- **WEB-KEYS-12** — The build must generate `<dir>/KEYS` when the set holds an
  OpenPGP key, with every such key in publication order.
- **WEB-KEYS-13** — The build must generate `<dir>/index.html`. The page must
  name the serial, the purpose, the type, the status, the fingerprint and the
  dates of each key. It must name the subject and the validity dates of a
  certificate, per WEB-X509-5. It must link each key file, and must list the
  bindings of each key, per WEB-TRUST-11.
- **WEB-KEYS-14** — The build must generate `.well-known/openpgpkey/hu/<hash>`
  for each email address that a key names, and must generate
  `.well-known/openpgpkey/policy` beside it. The site must hold one such tree,
  and each key directory must write into it. The file must hold the binary form
  of each OpenPGP key of that address, across every directory, in publication
  order. The order must come from the keys, and never from the directory that
  holds them. The policy file must name the site in the default language, per
  WEB-LANGUAGE-3, and no `org` word. One site serves one such file, and each
  directory writes the same bytes there.
- **WEB-KEYS-28** — An address whose keys are all `retired` must serve no file.
  A reader of that file encrypts a message with the key that it holds. The rule
  must read the address across every key directory of the site.
- **WEB-KEYS-15** — The build must generate `.well-known/security.txt` when a
  `keys` block names a contact. The file must carry an `Encryption` field when
  that block names a `url`. The key set of that block must also hold a `current`
  OpenPGP key. The field must name the first such key of the publication order
  of that block. The field must not name a key of another key directory, because
  a binding never crosses one. The checks must report the block that names the
  contact and a `url`, and holds no `current` OpenPGP key. The checks must not
  report that block when no other key directory holds such a key.
- **WEB-KEYS-16** — The inventory must name every path above, and each binding
  file, so the build and the checks read one list.
- **WEB-KEYS-17** — The build must sign nothing and must verify nothing.
- **WEB-KEYS-26** — The build must read each key file before it copies one. It
  must decode an armored key and a certificate, per WEB-X509-1, and it must hold
  a signify key to its own shape. A build that refuses a key must copy no key at
  all. A build that fails later can leave the keys that it wrote, and the checks
  report the tree.

### The checks

- **WEB-KEYS-18** — Each key file must have a `key` block, and each block must
  have a file. A binding file needs no block, and its target and its signer must
  each be a key of the directory.
- **WEB-KEYS-19** — Each name in the directory must match the key name pattern,
  or the binding name pattern.
- **WEB-KEYS-20** — Each purpose must hold exactly one `current` key.
- **WEB-KEYS-21** — `SHA256` must name every key file and every binding file
  with the digest that the file has, and must name nothing else.
- **WEB-KEYS-22** — The declared fingerprint of an OpenPGP key must equal the
  fingerprint that its body gives. The declared fingerprint of a certificate
  must equal the SHA-256 of its DER form.
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

<a id="web-trust"></a>

## The root of trust

One signify key of a key directory is the root of trust. Its purpose word is
`root`. The current root key signs the manifest, and every other key of the
directory is a subordinate key. A signify key is vendor neutral, and one line
holds it, so a consumer pins it with one line of its own.

A binding is a detached signature by one key over the public key file of another
key. A subordinate key binds to the current root, and that signature proves that
the holder of the root also holds the subordinate key. A retiring key binds to
the key that takes its place, so a consumer that trusts the old key reaches the
new one. The file name of a binding is `<target file>.<signer stem>.<ext>`. The
extension is `sig` for a signify signer, `asc` for an OpenPGP signer, and `p7s`
for an X.509 signer.

The generic parts live in the Fugu library. Those are the binding name pattern,
the retention rule, and one signer and one verifier for each key type. The
renderer and the verbs hold the wiring only.

- **WEB-TRUST-1** — Each key directory must hold exactly one `current` key of
  the purpose `root`, and that key must be a signify key. A mint and an import
  of the root purpose must refuse a key of another type. The mint must refuse
  before it generates one. A directory with no key is the one exception. The
  first mint of the root purpose must accept a directory whose keys hold no
  root, and must bind each of them per WEB-TRUST-7.
- **WEB-TRUST-2** — The current root key must sign `SHA256`, and no other key
  must sign it. A step of a subordinate purpose must take the private half of
  the current root as `--signer`.
- **WEB-TRUST-3** — Each `current` and `next` key of a subordinate purpose must
  hold one binding over the public key file of the current root.
- **WEB-TRUST-4** — A promote must write a chain binding: the retiring key signs
  the public key file of the key that becomes current. The promote must take the
  private half of the retiring key as `--retiring`.
- **WEB-TRUST-5** — A chain binding must stay published, as a retired key does.
  A step that retires a subordinate key must remove the binding of WEB-TRUST-3
  that the key holds.
- **WEB-TRUST-6** — The manifest must name every key file and every binding
  file, and nothing else.
- **WEB-TRUST-7** — A first root mint and a root promote must write the binding
  of each subordinate key again, in the one step. The step must take the private
  half of each `current` and `next` subordinate key as `--bind <stem>=<path>`.
  It must refuse before it writes when one is absent. A root promote must remove
  each binding whose target is the retired root, except a chain binding of
  WEB-TRUST-4.
- **WEB-TRUST-8** — A step must sign each binding with the signer of the type of
  its signer key. It must verify each binding that it writes against the public
  key of the signer, before one byte reaches the directory. A signature that the
  key does not verify must fail the step.
- **WEB-TRUST-9** — `fuguweb check` must verify each binding against the public
  key of its signer. It must use the verifier of that type in the Fugu library.
  A signify binding needs no command. An absent gpg(1) or openssl(1), for a type
  that the directory holds, is a problem. The check must verify no `SHA256.sig`,
  per WEB-KEYS-33.
- **WEB-TRUST-10** — The check must hold each binding to the retention rule. A
  binding whose signer is `current` or `next` must target the current root. A
  binding whose signer is `retired` must target a key of the same purpose with a
  higher serial. Every other binding is a problem.
- **WEB-TRUST-11** — The human page must list each binding under the key that it
  targets, with the signer and a link to the file.
