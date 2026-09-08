# 002 — The key rotation

## Status

Proposed. It can land now. Nothing waits on it.

Implements: WEB-ROTATE

## Purpose

FuguBSD signs each release, and a consumer install verifies the signature
against a published public key. No key is published, so no consumer can verify
anything, and three consumers cannot sync the shared tooling.

FuguWeb already reads a key directory. `fuguweb build` copies each key file and
generates the `KEYS` file, the human page and the well-known tree.
`fuguweb check` holds the directory to WEB-KEYS. Nothing writes the directory,
so no key can arrive.

This plan adds the writer. `fuguweb rotate-key` mints a key and promotes it, and
it shares the name pattern, the status vocabulary and the manifest with the
reader.

## Why the command belongs here

The rotation needs `Fugu::Config`, `Fugu::KeyDir` and `Fugu::Signify`. FuguWeb
depends on all three, and it owns the key directory contract in WEB-KEYS. The
tests therefore run against the real modules, in a repository that installs Fugu
already.

FuguBSD/Website is the publication point, and its D-01 holds it to site content
with no application code. The rotation workflow of that repository calls
`fuguweb`, as its build and its check already do.

## Evidence

### The reader is complete and tested

`App::FuguWeb::Keys` holds the wiring, and `Fugu::KeyDir` holds the generic
parts. `t/fuguweb/keys.t` covers them. A differential fuzzer of 6,255 trials
found no case where the build removes what the clean refuses.

`Fugu::KeyDir` gives `parse_name`, `name_for`, `next_serial`, `order` and
`check_statuses`. `Fugu::Signify` gives `parse_manifest`, `write_manifest` and
`verify`. The writer needs no new generic code.

### An earlier attempt failed a review panel

A first version of this work lived in FuguBSD/Website as `scripts/rotate-key`. A
three-seat panel reproduced defects that destroy key material. This plan states
the rule for each one, so the implementation cannot repeat it.

| The defect                                                     | The rule that stops it |
| -------------------------------------------------------------- | ---------------------- |
| The status lookup assumed `current` for a key with no block.   | WEB-ROTATE-4           |
| A second mint wrote two `next` keys and lost a private key.    | WEB-ROTATE-5           |
| The manifest signer fell back to the key that the run minted.  | WEB-ROTATE-6           |
| Nothing verified that the signature came from the current key. | WEB-ROTATE-7           |
| The old signature went before the new one existed.             | WEB-ROTATE-8           |
| Two writes of the description left it with two `current` keys. | WEB-ROTATE-10          |
| No test read the digest against the bytes of the key file.     | WEB-ROTATE-11, -12     |

### signify is a new test dependency

The command signs, so `deps/Linux.txt` takes `test pkg signify-openbsd`. The
runtime needs no new dependency: a build signs nothing, and it verifies nothing.

## The change

1. `lib/App/FuguWeb/Rotate.pm` and its sidecar hold the rotation. The module
   reads and writes the key directory and the description. It runs `signify(1)`
   and nothing else.
2. `lib/App/FuguWeb/CLI.pm` gains the `rotate-key` command, with the step, the
   purpose, the secret path, the signer path, and the bootstrap words.
3. `t/fuguweb/rotate.t` covers the module against the real `signify(1)`.
4. `deps/Linux.txt` takes `test pkg signify-openbsd`.
5. `spec/STATUS.md` sets WEB-ROTATE.
6. This plan directory goes in the same change.

## What this plan does not do

It writes no secret and it opens no pull request. The workflow of
FuguBSD/Website holds the credential, stores the private key in an organization
secret, and declares the public key in FuguBSD/Tooling. WEB-ROTATE-14 states the
boundary.

It adds no purpose but `release`. The name pattern takes any purpose word, and
the caller decides.
