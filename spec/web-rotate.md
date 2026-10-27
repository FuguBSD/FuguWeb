# The rotation

This document holds the key rotation, the OpenPGP rotation, the certificate and
the workflows. [web-keys.md](web-keys.md) holds the key directory, and the
conventions of [index.md](index.md) apply.

<a id="web-rotate"></a>

## The key rotation

`fuguweb build` and `fuguweb check` read the key directory, and the key verbs
write it. The reader and the writer share one implementation of the name
pattern, the status vocabulary and the manifest.

A consumer verifies a release against the copy of the public key that it holds.
A release that a new key signs therefore fails in each consumer that holds the
old copy. One rotation runs in two steps, and the trust order carries the gap. A
`mint` makes the next key, and a `promote` makes it current.

The verbs sign, and the build signs nothing (WEB-KEYS-17). A verb signs with the
signer of the key type in the Fugu library, and it runs no command of its own. A
signify key signs through `Fugu::Signify`, and a key of another type signs
through `gpg(1)` or `openssl(1)`. The check verifies a signify binding with no
command, and it runs the command of another type, per WEB-TRUST-9.

- **WEB-ROTATE-1** — The verbs must be `fuguweb mint-key`, `fuguweb import-key`
  and `fuguweb promote-key`. Each verb must take a `--purpose` word. `mint-key`
  must take a `--type`, and the default must be `signify`.
- **WEB-ROTATE-2** — A mint must take the next serial of the purpose. It must
  generate a key of the type that `--type` names: a signify pair, or an OpenPGP
  key per WEB-OPENPGP-1. The signify pair and the OpenPGP secret half must take
  no passphrase. It must write the public half into the key directory. It must
  write the private half to the named path, and that file must take no group
  mode and no other mode.
- **WEB-ROTATE-3** — A mint must give the new key the status `current` when the
  purpose holds no current key, and the status `next` otherwise.
- **WEB-ROTATE-4** — The command must read the status of each key from the
  description, and it must assume no status. A key file with no `key` block, and
  a `key` block with no file, must each fail the command.
- **WEB-ROTATE-5** — A mint must refuse a purpose that holds a `next` key
  already, and it must refuse before it generates a pair. A caller stores the
  private half of each mint in one place, so a second `next` key loses the
  private half of the first.
- **WEB-ROTATE-6** — The current root key must sign the manifest. A first root
  mint must sign its own manifest, and a root promote must sign with the new
  root. Every other step must take the private half of the current root as
  `--signer`, per WEB-TRUST-2.
- **WEB-ROTATE-7** — The command must verify the new signature against the
  published public key of the signer. A signature that the key does not verify
  must fail the command.
- **WEB-ROTATE-8** — The command must hold the old signature until a verified
  signature stands in its place. It must leave no directory that holds a
  manifest and no signature.
- **WEB-ROTATE-9** — A promote must make the `next` key of the purpose current.
  It must retire the key that was current with an `until` date. It must write
  the chain binding of WEB-TRUST-4, and must remove each binding that
  WEB-TRUST-5 and WEB-TRUST-7 name.
- **WEB-ROTATE-10** — The command must write the description once in each run. A
  second write leaves the file half changed when it fails.
- **WEB-ROTATE-11** — The command must read the description back after it
  writes, and it must confirm the status of each key that it changed.
- **WEB-ROTATE-12** — The resulting key set must satisfy the status rules of
  `Fugu::KeyDir`, and the command must check the set before it returns.
- **WEB-ROTATE-13** — The command must print one `name=value` line for each fact
  that a caller needs. The facts are the file name, the stem, the serial and the
  status. A promote must add the retired name. A step that writes a key file
  must add the digest and the URL of that file.
- **WEB-ROTATE-14** — The command must reach no network and must hold no token.
  The caller holds the credential.
- **WEB-ROTATE-16** — A mint must record the date of the run as `since` on the
  new `key` block, whatever the type of the key. A promote must record it as
  `until` on the block of the key that it retires. Both dates must read in UTC.
- **WEB-ROTATE-17** — An absent `signify(1)` must fail the command with the exit
  code of a missing tool. A caller then tells it from a rotation that failed.
- **WEB-ROTATE-18** — A mint must refuse a `--secret` path that stands already,
  and one that names the signer. The private half of a key is the one thing that
  a rotation cannot make again. A caller holds each one in one place.
- **WEB-ROTATE-19** — A key directory must hold one root purpose and any number
  of other purposes. One manifest covers the directory, and the current root key
  signs it. A step of another purpose must fail when the directory holds no
  current root.
- **WEB-ROTATE-20** — A step must refuse a key set that breaks the status rules
  of `Fugu::KeyDir`, before it writes. A step over such a set could ask a
  retired key to sign. A directory with no key is the state of a site before its
  first mint, and it must stand. A directory whose keys hold no root must stand
  for the first root mint alone, per WEB-TRUST-1.
- **WEB-ROTATE-21** — The key directory word must name one directory below the
  source directory, as WEB-KEYS-29 holds it. The word is `--dir`, and it selects
  the directory that the step writes. A description with one `keys` block must
  need no such word, and a description with several must refuse a step without
  it.
- **WEB-ROTATE-15** — A directory that no `keys` block names must take one, with
  the organization word and the published prefix that the caller names. The
  block and the first key must arrive in one change, because a block that names
  an empty directory fails every build. A second key directory of a site must
  arrive the same way.
- **WEB-ROTATE-22** — A step that makes a key directory must state that intent.
  The word is `--bootstrap`, and `mint-key` and `import-key` alone must take it.
  A step without it must refuse a `--dir` that no `keys` block names, and must
  refuse before it writes one byte. Each directory holds a root of trust of its
  own, so a mistyped `--dir` would otherwise publish a second root in silence.

<a id="web-openpgp"></a>

## The OpenPGP rotation

The renderer publishes an OpenPGP key, and the verbs mint one. gpg(1) makes the
key and the binding, in a temporary home that dies with the run. The Fugu
library holds each call, and the verbs hold the wiring.

- **WEB-OPENPGP-1** — `fuguweb mint-key --type openpgp` must take an `--email`
  address. It must generate one Ed25519 primary key with one Curve25519
  encryption subkey, and that address as its user id. It must write the armored
  public half into the directory as `.asc`, and the armored secret half to
  `--secret`. The `Encryption` field of WEB-KEYS-15 names the key, and a reader
  encrypts to the subkey.
- **WEB-OPENPGP-2** — The mint must write the `email` and the `fingerprint` of
  the new key into its `key` block. It must read the fingerprint from the key
  that it generated, and never from an argument.
- **WEB-OPENPGP-3** — The mint must take an optional `--expires` date of the
  form `YYYY-MM-DD`. It must set the key expiry to the start of that date in
  UTC. It must refuse a date that is not after the day of the run. The reason
  must name the date that the caller gave. A mint without one must set no
  expiry. The key directory retires a key with an `until` date, and the machine
  rotates.
- **WEB-OPENPGP-4** — The check must report a `current` or `next` OpenPGP key
  whose expiry has passed. It must report a `current` key that expires within 30
  days, when its purpose holds no `next` key. A step of the rotation must not
  fail for either report. An expired `current` key stays `current`, so a step
  that failed for that report could never mint the successor. The 30-day report
  reads the whole directory, so it would fail a step of another purpose, and
  that step cannot answer it. A promote of an expired OpenPGP key fails in the
  signer. WEB-TRUST-4 makes the retiring key sign the chain binding, and gpg(1)
  signs nothing with an expired key.
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
  the caller, and the subordinate purposes of a root step. They must take the
  `--email` and `--expires` of an OpenPGP mint, and the `--file` of an import.
  Each of the three is optional. They must take the `--bootstrap` of a step that
  makes the key directory, per WEB-ROTATE-22, and that input is optional too.
  Every step must name the directory, a promote included, because a site can
  hold several.
- **WEB-ACTIONS-2** — The workflow must output each fact of WEB-ROTATE-13, and
  the digest and the URL of a new key file. A caller declares the key with them.
- **WEB-ACTIONS-3** — Two composite actions must hold the slots.
  `actions/keys-slot` reads the slot variable of each purpose that the caller
  names, and writes the working key files. `actions/keys-store` writes a secret
  from a file and moves the variable. A caller can compose the two on its own.
  One place must read a slot variable, and the workflow must read none itself.
  The `active` and `idle` outputs of `actions/keys-slot` must answer the first
  purpose of the list.
- **WEB-ACTIONS-4** — Each secret must reach a step through the environment, and
  never through the script text. The workflow must read a secret by a name that
  an input forms, through the JSON form of the `secrets` context.
- **WEB-ACTIONS-5** — The workflow must install `fuguweb` with `make deps` of
  the caller, from the release tarballs that the deps manifest of the caller
  pins. It must install nothing of its own. Each install must run before the
  step that mints a token. The workflow must name the install root. It must give
  the module path and the command path of that root to each step that follows.
- **WEB-ACTIONS-6** — The workflow must read the root slot, the purpose slot,
  and the retiring key. A root step that binds each subordinate key again must
  also read the slot of each subordinate purpose. Every other step must read
  none of them. It must give each slot to the verb as a file. A slot that holds
  nothing must leave an empty file.
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
