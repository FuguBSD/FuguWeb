# 004 — The OpenPGP rotation

## Status

Proposed. It waits on plan 003, and on a Fugu release that holds the generator
and the detached signature of `Fugu::OpenPGP`, per Fugu LIB-OPENPGP.

Implements: WEB-OPENPGP. Extends: WEB-ROTATE.

## Purpose

The renderer publishes an OpenPGP key: the `KEYS` file, the Web Key Directory
and `security.txt` each read one. No verb mints one, so an operator makes the
key by hand, exports it, and writes the `key` block. A hand-made key defeats the
rule that no human handles a private key.

This plan adds the OpenPGP key to `mint-key`. The verb generates the key and
publishes the public half. It hands the secret half to the caller as a file, and
binds the key to the root.

## Evidence

`Fugu::OpenPGP` decodes an armored key and computes the fingerprint and the Web
Key Directory hash, with no command. It generates nothing and it signs nothing.
The Fugu plan adds the command parts, through `gpg(1)` in a temporary home.

The research names the key transition statement as the OpenPGP practice: one
text that both keys sign. The chain binding of WEB-TRUST-4 gives the same proof
in the shape of this directory, so this plan adds no statement file.

`keys.openpgp.org` strips third-party certifications, and a Web Key Directory on
the domain of the publisher keeps them. The renderer serves that directory
already, so this plan changes nothing there.

## The rule changes

### WEB-ROTATE

- WEB-ROTATE-2 takes the type from `--type`: a signify pair, or an OpenPGP key
  per WEB-OPENPGP-1.
- WEB-ROTATE-16 records `since` for an OpenPGP key as it does for a signify key.

## The change

1. `lib/App/FuguWeb/Rotate.pm` calls `Fugu::OpenPGP` for the key, the export,
   the binding and the expiry. It writes `email` and `fingerprint` into the
   `key` block.
2. `lib/App/FuguWeb/CLI.pm` gives `mint-key` the `--email` and `--expires`
   options.
3. `lib/App/FuguWeb/Keys.pm` verifies an `.asc` binding, and reads the expiry of
   each OpenPGP key for the check.
4. `man/fuguweb/fuguweb.1` describes the OpenPGP mint.
5. `t/fuguweb/rotate.t` covers the mint, the binding and the expiry against the
   real `gpg(1)`, and skips when the tool is absent.
6. `deps/Linux.txt` and `deps/Darwin.txt` take `runtime pkg gnupg`.
7. `spec/STATUS.md` sets WEB-OPENPGP, and this plan directory goes in the same
   change.

## What this plan does not do

It publishes no revocation certificate. A retired key stays published with an
`until` date, and a compromise takes a human decision.

It imports no key that another tool made. `import-key` of plan 005 takes any
type, and an OpenPGP key enters through it.
