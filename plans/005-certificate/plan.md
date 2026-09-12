# 005 — The certificate

## Status

Proposed. It waits on plan 003, and on a Fugu release with `Fugu::X509`, per
Fugu LIB-X509. That release must also hold the `pem` extension of
`Fugu::KeyDir`, per Fugu LIB-KEYDIR.

Implements: WEB-X509. Extends: WEB-KEYS. Extends: WEB-OUTPUT.

## Purpose

A publisher signs a macOS binary with a code signing certificate of Apple
Developer ID. Nothing binds that certificate to the organization. A reader of a
signed binary sees a team identifier, and no page of the publisher names it.

This plan adds the X.509 certificate as the third key type. A verb imports the
certificate, and the private key binds it to the root. The human page names the
subject, the fingerprint and the validity dates.

## Evidence

The research reads the Apple documents. A Developer ID certificate is valid for
five years. A signed, timestamped and notarized binary stays valid after the
certificate expires, and only a new signature needs a new certificate. Apple's
own designated requirement pins the team identifier and not the leaf hash,
because the leaf hash changes at each renewal.

The directory therefore treats a renewal as a rotation: the new certificate
enters as `next`, and a promote retires the old one. The page names the subject,
which carries the team identifier, and the fingerprint, which pins one leaf.

No module of Fugu reads a certificate. The Fugu plan adds `Fugu::X509`, with a
DER reader for the subject and the dates, and a CMS signer and verifier through
`openssl(1)`.

## The rule changes

### WEB-KEYS

- WEB-KEYS-5 takes `.pem` as a third extension.
- WEB-KEYS-7 takes `fingerprint` on a certificate too, per WEB-X509-4.
- WEB-KEYS-13 adds the subject and the validity dates to the human page, per
  WEB-X509-5.
- WEB-KEYS-22 compares the SHA-256 fingerprint of a certificate.
- WEB-KEYS-26 decodes a certificate before it copies one, per WEB-X509-1.

### WEB-OUTPUT

- WEB-OUTPUT-10 adds the `.pem` key file to the shapes of the key directory.

## The change

1. `lib/App/FuguWeb/Rotate.pm` gains the import: the copy of the certificate,
   the `key` block with its fingerprint, and the `.p7s` binding.
2. `lib/App/FuguWeb/CLI.pm` accepts `--type x509` on `import-key`.
3. `lib/App/FuguWeb/Keys.pm` decodes a certificate, verifies a `.p7s` binding,
   compares the fingerprint, and reports an expired or a not yet valid
   certificate.
4. `lib/App/FuguWeb/Keys.pm` skips a certificate in the `KEYS` file and the Web
   Key Directory.
5. `man/fuguweb/fuguweb.1` describes the import.
6. `t/fuguweb/rotate.t` and `t/fuguweb/keys.t` cover the import and the checks
   against a certificate that the test makes with `openssl(1)`.
7. `deps/Linux.txt` and `deps/Darwin.txt` take `runtime pkg openssl`.
8. `spec/STATUS.md` sets WEB-X509, and this plan directory goes in the same
   change.

## What this plan does not do

It signs no binary and it notarizes nothing. The certificate signs binaries in
the release workflow of a project, and this directory publishes the certificate
alone.

It reads no PKCS#12 file. The slot holds the PEM private key, per WEB-X509-3.
The operator converts a PKCS#12 file once, with `openssl pkcs12`, before the
first secret write. Neither the verbs nor the workflow of plan 006 read one.

It checks no issuer. `Fugu::X509` knows no issuer by name, and the root manifest
vouches for the certificate.
