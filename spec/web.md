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
  the purpose `root`, and that key must be a signify key. A directory with no
  key is the one exception. The first mint of the root purpose must accept a
  directory whose keys hold no root, and must bind each of them per WEB-TRUST-7.
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
  It must refuse before it writes when one is absent.
- **WEB-TRUST-8** — A step must verify each binding that it writes against the
  public key of the signer, before one byte reaches the directory. A signature
  that the key does not verify must fail the step.
- **WEB-TRUST-9** — `fuguweb check` must verify each binding against the public
  key of its signer, with the tool of that type. It must verify no `SHA256.sig`,
  per WEB-KEYS-33. An absent tool for a type that the directory holds is a
  problem.
- **WEB-TRUST-10** — The check must hold each binding to the retention rule. A
  binding whose signer is `current` or `next` must target the current root. A
  binding whose signer is `retired` must target a key of the same purpose with a
  higher serial. Every other binding is a problem.
- **WEB-TRUST-11** — The human page must list each binding under the key that it
  targets, with the signer and a link to the file.

<a id="web-openpgp"></a>

## The OpenPGP rotation

The renderer publishes an OpenPGP key, and no verb mints one. This unit adds the
OpenPGP key to the verbs. gpg(1) makes the key and the binding, in a temporary
home that dies with the run. The Fugu library holds each call, and the verbs
hold the wiring.

- **WEB-OPENPGP-1** — `fuguweb mint-key --type openpgp` must take an `--email`
  address, and must generate one Ed25519 key with that address as its user id.
  It must write the armored public half into the directory as `.asc`, and the
  armored secret half to `--secret`.
- **WEB-OPENPGP-2** — The mint must write the `email` and the `fingerprint` of
  the new key into its `key` block. It must read the fingerprint from the key
  that it generated, and never from an argument.
- **WEB-OPENPGP-3** — The mint must take an optional `--expires` date, and must
  set the key expiry to it. A mint without one must set no expiry. The key
  directory retires a key with an `until` date, and the machine rotates.
- **WEB-OPENPGP-4** — The check must report a `current` or `next` OpenPGP key
  whose expiry has passed. It must report a `current` key that expires within 30
  days, when its purpose holds no `next` key.
- **WEB-OPENPGP-5** — A binding by an OpenPGP key must be an armored detached
  signature. The verifier must import the one public key of the signer into an
  empty home, and a signature of another key must fail.
- **WEB-OPENPGP-6** — An absent gpg(1) must fail a step with the exit code of a
  missing tool, as WEB-ROTATE-17 holds for signify(1).

<a id="web-x509"></a>

## The certificate

An X.509 certificate is the third key type. A code signing certificate of Apple
Developer ID is one such key, and the renderer knows no issuer by name. An
issuer makes the certificate, so no verb mints one: a verb imports it. The
private key stays with the publisher, and it makes the binding.

- **WEB-X509-1** — The extension `.pem` must select the type `x509`. The file
  must hold one PEM certificate. The check must decode it, and must reject a
  file that holds a private key or a second block.
- **WEB-X509-2** — `fuguweb import-key` must take `--type`, `--purpose`,
  `--file` and `--secret`. It must copy the certificate into the directory under
  the next key name of the purpose, with the status of WEB-ROTATE-3. It must
  write the binding with the private key. An import of another type must take
  the same options, so a key that another tool made can enter the directory.
- **WEB-X509-3** — The `--secret` of an X.509 key must be an unencrypted PEM
  private key. The verbs take no passphrase. A caller that holds a PKCS#12 file
  converts it first.
- **WEB-X509-4** — A `key` block of an X.509 key must take an optional
  `fingerprint` of 64 hexadecimal characters: the SHA-256 of the DER form. The
  import must write it, and the check must compare it, as WEB-KEYS-22 holds for
  an OpenPGP key.
- **WEB-X509-5** — The human page must name the subject and the validity dates
  of a certificate beside the fingerprint. A reader of the page compares the
  subject with what a signed binary reports.
- **WEB-X509-6** — The check must report a `current` or `next` certificate whose
  `notAfter` has passed, and one whose `notBefore` has not come. It must report
  a `current` certificate that expires within 30 days, when its purpose holds no
  `next` key.
- **WEB-X509-7** — A binding by an X.509 key must be a detached CMS signature in
  PEM form. The verifier must pin the one certificate of the signer, and must
  check no chain. The root manifest vouches for the certificate.
- **WEB-X509-8** — The `KEYS` file and the Web Key Directory must skip a
  certificate. Each one serves an OpenPGP reader.
- **WEB-X509-9** — An absent openssl(1) must fail a step with the exit code of a
  missing tool.

<a id="web-actions"></a>

## The workflows

A publisher stores each private key in an organization secret, and no human
handles it. This repository provides the GitHub Actions parts of that: one
reusable workflow, and the composite actions that it composes. A caller
repository holds the credential, the trigger, and its own follow-up. The verbs
hold every trust rule, and the workflow holds the order of the steps.

The pattern of the secret names is `<PREFIX>_<PURPOSE>_KEY_A`,
`<PREFIX>_<PURPOSE>_KEY_B`, and the variable `<PREFIX>_<PURPOSE>_SLOT`. The two
secret names are fixed for one purpose, and the variable moves. The prefix is an
input, so an organization keeps the names that it has.

- **WEB-ACTIONS-1** — The reusable workflow `.github/workflows/keys-rotate.yml`
  must run one step of one purpose in the tree of the caller. Its inputs must
  name the step, the type, the purpose, and the directory. They must name the
  organization word, the published prefix, the environment, and the secret
  prefix. They must name the owner, the visibility list, the publish workflow of
  the caller, and the subordinate purposes of a root step.
- **WEB-ACTIONS-2** — The workflow must output each fact of WEB-ROTATE-13, and
  the digest and the URL of a new key file. A caller declares the key with them.
- **WEB-ACTIONS-3** — Two composite actions must hold the slots.
  `actions/keys-slot` reads the slot variable of one purpose and writes the
  working key files. `actions/keys-store` writes a secret from a file and moves
  the variable. A caller can compose the two on its own.
- **WEB-ACTIONS-4** — Each secret must reach a step through the environment, and
  never through the script text. The workflow must read a secret by a name that
  an input forms, through the JSON form of the `secrets` context.
- **WEB-ACTIONS-5** — The workflow must install `fuguweb` with `make deps` of
  the caller, from the release tarballs that the deps manifest of the caller
  pins. It must install nothing of its own. Each install must run before the
  step that mints a token.
- **WEB-ACTIONS-6** — The workflow must read the root slot, the purpose slot,
  and the retiring key. It must give each one to the verb as a file. A slot that
  holds nothing must leave an empty file.
- **WEB-ACTIONS-7** — The workflow must mask each new private key, and must
  write it into the idle slot before it commits. It must move the variable last,
  after the published site serves each file that the run wrote, byte for byte.
- **WEB-ACTIONS-8** — The workflow must start the publish workflow of the caller
  itself, and must watch no run of it. A push that `GITHUB_TOKEN` makes raises
  no workflow run.
- **WEB-ACTIONS-9** — The workflow must hold no organization name, no domain,
  and no repository list. Each one is an input.
- **WEB-ACTIONS-10** — The workflow must open no pull request, and must declare
  no key anywhere. The caller reads the outputs.
- **WEB-ACTIONS-11** — The workflow must pin each action that it uses to a
  commit, because it runs beside a private key.
- **WEB-ACTIONS-12** — The workflow must remove every private key file that it
  wrote, whatever the outcome of the run.
- **WEB-ACTIONS-13** — The test `t/ci/keys-rotate.t` must hold the order of the
  steps, and each guard above, as text.
- **WEB-ACTIONS-14** — `environment` must bind in the callee job, from the
  input. `permissions`, `concurrency`, and `secrets: inherit` must stay in the
  caller.

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
