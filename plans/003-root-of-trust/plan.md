# 003 — The root of trust

## Status

Proposed. It waits on a Fugu release with the signer of `Fugu::Signify`, per
Fugu LIB-SIGNIFY. That release must also hold the binding names of
`Fugu::KeyDir`, per Fugu LIB-KEYDIR. Plan 004, plan 005 and plan 006 wait on
this plan.

Implements: WEB-TRUST. Extends: WEB-ROTATE. Extends: WEB-KEYS. Extends:
WEB-OUTPUT.

## Purpose

The key directory holds one purpose, and the current key of that purpose signs
the manifest. A directory therefore holds signify keys of one purpose and
nothing else. An OpenPGP key or a certificate can sit in the directory, and
nothing binds it to the key that signs releases.

This plan makes one signify key the root of trust of a directory, per D-02. The
root signs the manifest, and each other key binds to the root with a signature
of its own. A consumer that pins the root can then trust every key of the
directory. A consumer that trusts an old key reaches the new one.

## Evidence

### What stands

`App::FuguWeb::Rotate` mints and promotes a signify key, and it stages every
file before one byte reaches the tree. `Fugu::KeyDir` holds the name pattern and
the status rules. `Fugu::Signify` verifies a signature and reads and writes the
manifest. `t/fuguweb/rotate.t` covers the two steps against the real
`signify(1)`.

The rotation runs `signify -G` and `signify -S` itself, in `Rotate.pm`. Those
two calls are generic, and the Fugu plan moves them into `Fugu::Signify`.

### What the research says

OpenBSD names each key by its period, and the current release ships the next
key. An upgrade chain therefore never fetches a key out of band. The Update
Framework accepts a new root only when the old root signs the document that
introduces it. An OpenPGP key transition statement carries both fingerprints and
both signatures. Debian carried two signatures on each `Release` file through
one key transition.

The chain binding of WEB-TRUST-4 is that rule in the smallest form: the retiring
key signs the file of the new key. The binding of WEB-TRUST-3 adds a proof of
possession, which none of those systems carries. A root that signs a manifest
claims each key. A key that signs the root proves that one holder holds both.

### The manifest stays

The research favors one signed JSON manifest with a version and an expiry. This
plan keeps the `SHA256` form. The consumer install of `scripts/deps` reads it
already. The file name carries the serial and the purpose, and the digest pins
the bytes of each key. No consumer reads the manifest live, so an expiry stops
no attack here. A later plan can add one when a consumer does.

## The rule changes

### WEB-ROTATE

- The intro sentence that names `signify(1)` as the one need of FuguWeb changes.
  The verbs run `signify(1)` through `Fugu::Signify`, and the check runs no
  command, per WEB-TRUST-9.
- WEB-ROTATE-1 names three verbs in place of one: `fuguweb mint-key`,
  `fuguweb import-key` and `fuguweb promote-key`. `rotate-key` goes. Each verb
  takes `--purpose`, and `mint-key` takes `--type` with the default `signify`.
- WEB-ROTATE-6 names the current root as the signer of the manifest. The first
  root mint signs its own manifest, and a root promote signs with the new root.
  Every other step takes `--signer`, per WEB-TRUST-2.
- WEB-ROTATE-9 adds the chain binding and the removal of the retired binding to
  a promote, per WEB-TRUST-4 and WEB-TRUST-5.
- WEB-ROTATE-13 adds the digest and the URL of a new key file to the facts.
- WEB-ROTATE-19 changes: a directory holds one root purpose and any number of
  other purposes.
- WEB-ROTATE-20 accepts a directory with keys and no root, for the first root
  mint alone, per WEB-TRUST-1.

### WEB-KEYS

- WEB-KEYS-11, WEB-KEYS-16 and WEB-KEYS-21 name the binding files beside the key
  files. The build copies them, the inventory names them, and the manifest names
  them.
- WEB-KEYS-13 adds the bindings to the human page, per WEB-TRUST-11.
- WEB-KEYS-18 and WEB-KEYS-19 accept a binding name, and hold it to two keys of
  the directory.

### WEB-OUTPUT

- WEB-OUTPUT-10 adds the binding file to the shapes of the key directory.

## The verbs

Each verb reads each private half as a file, per D-03.

| Option                 | Meaning                                                      |
| ---------------------- | ------------------------------------------------------------ |
| `--secret <path>`      | The private half of the key that the step makes or promotes. |
| `--signer <path>`      | The private half of the current root, which signs `SHA256`.  |
| `--retiring <path>`    | The private half of the key that a promote retires.          |
| `--bind <stem>=<path>` | The private half of one subordinate key, for a root step.    |
| `--file <path>`        | The public key file that `import-key` reads.                 |

Every step takes `--signer`, with two exceptions. The first root mint takes
none: no root exists, and the new key signs. A root promote takes none: the new
root signs from `--secret`, and the retiring root comes as `--retiring`. A root
mint of a `next` key takes `--secret` and `--signer`, because the current root
signs, per WEB-TRUST-2. A first root mint takes `--secret` and each `--bind`. A
root promote takes `--secret`, `--retiring` and each `--bind`. A subordinate
mint takes `--secret` and `--signer`. A subordinate promote takes `--signer` and
`--retiring`. An import takes `--file` beside the options of a mint of its
purpose, per WEB-X509-2.

## The change

1. `lib/App/FuguWeb/Rotate.pm` gains the root rule, the bindings and the chain,
   and calls `Fugu::Signify` for each key pair and each signature. It runs no
   command of its own.
2. `lib/App/FuguWeb/CLI.pm` replaces `rotate-key` with `mint-key`, `import-key`
   and `promote-key`. `import-key` takes a signify key in this plan, and plan
   005 adds the certificate.
3. `lib/App/FuguWeb/Keys.pm` reads the binding names, verifies each binding,
   holds the retention rule, and lists the bindings on the human page.
4. `lib/App/FuguWeb/Site.pm` and `Config.pm` take the binding shape.
5. `man/fuguweb/fuguweb.1` describes the three verbs and the trust order.
6. `t/fuguweb/rotate.t` and `t/fuguweb/keys.t` cover each rule of WEB-TRUST.
   Each new test carries the mutation that it catches.
7. `deps/Linux.txt` pins the Fugu release that holds the signer.
8. `spec/STATUS.md` sets WEB-TRUST, and this plan directory goes in the same
   change.

## What this plan does not do

It publishes no key. The site of the organization holds one self-signed release
key, and its check fails under this plan until a root exists. The caller of that
site runs the first root mint with `--bind` for the release key. It pins the new
`fuguweb` release in the same change.

It adds no OpenPGP mint and no certificate. Plan 004 and plan 005 hold them, and
each one reads the bindings of this plan.

It changes no consumer. `scripts/deps` of Tooling pins the release key by its
digest, and the root gives it nothing to read yet.
