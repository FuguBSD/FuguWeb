# 001 — The key directory of a FuguBSD site

## Status

Proposed.

## Purpose

A FuguBSD site publishes the public keys of the organization. FuguBSD/Website
holds the first one, and every other site publishes its keys the same way.

This plan wires that directory into `fuguweb`. The generic parts already exist:
Fugu v0.3.0 holds `Fugu::KeyDir`, `Fugu::OpenPGP`, and the manifest parser and
writer of `Fugu::Signify`. FuguWeb reads the description, calls those modules,
writes the output tree, and checks the result. Nothing generic lands here.

## Why this blocks the organization

`scripts/deps` of the org pack verifies a download in two tiers. The digest tier
needs a recorded sha256. The signify tier needs a published key, and
`deps/KEYS.txt` declares each key by URL and digest.

No key is published, so no entry can take the signify tier. The first key
publishes through this work, so this plan blocks:

- the release signature of the Perl distributions, in FuguBSD/Tooling;
- the pack sync of FuguTTX, FuguVM and FuguWeb, each of which holds a `dist`
  entry on a stable URL;
- the rotation workflow of FuguBSD/Website, which needs somewhere to publish.

## Evidence

### The build copies no directory of the source tree

`App::FuguWeb::Config->assets` lists the source directory one level deep, and it
keeps a name only when `-f` holds:

```perl
return
    grep { !/^\./ && !/\.body\.html$/ && !/\.md$/ && -f "$dir/$_" }
    @$names;
```

`App::FuguWeb::list_dir` reads one level, and it recurses into nothing. A
directory under `web/` therefore reaches no output today. Measured on
2026-09-07, against `main` at `a9d6362`.

A key directory needs a subdirectory, because the published paths are
`keys/<stem>.pub` and `.well-known/openpgpkey/`. The build needs new code for
it, and no arrangement of the current asset rule serves it.

### The modules of Fugu are in place

Fugu v0.3.0 holds each generic part. `Fugu::KeyDir` carries the name pattern,
the type of a key from its extension, the status vocabulary, the publication
order, and the text of the generated files. `Fugu::OpenPGP` decodes an armored
key, computes the v4 fingerprint, and computes the Web Key Directory hash.

`Fugu::KeyDir` states that each purpose holds exactly one `current` key (Fugu
LIB-KEYDIR-2). A signify key and an OpenPGP key therefore take two purposes, and
not one purpose with two extensions.

### The renderer runs no key command

`Fugu::KeyDir` and `Fugu::OpenPGP` run no command, and `Fugu::Signify` needs
`signify(1)` for a verification only. A site build neither signs nor verifies,
so the build needs neither `gpg(1)` nor `signify(1)`. The manifest pair is a
source file, because the build cannot sign.

## Design

### The keys block

One `keys` block names the source directory under `web/` and the organization
word. A `contact` value turns on `security.txt`.

    keys "keys" {
    	org     = fugubsd
    	contact = mailto:security@fugubsd.org
    }

One `key` block for each key holds the status and the dates. An OpenPGP key also
holds the email and the declared fingerprint.

    key "fugubsd-1-release" {
    	status = current
    	since  = 2026-09-06
    }

The block name is the stem of the key file. The type comes from the extension of
the file on disk, so the description repeats it nowhere. The status is
`current`, `next` or `retired`.

A description with no `keys` block builds a site with no key directory, so every
current consumer keeps its behavior.

### The build

`fuguweb build` copies each key file, and it copies `SHA256` and `SHA256.sig` as
they stand. It generates `KEYS`, `index.html`, the `openpgpkey` tree, and
`security.txt` through the Fugu modules.

The inventory of the output must name each generated path, so the build and the
checks read one list. `App::FuguWeb::Config->inventory` gains the key paths.

### The check

`fuguweb check` holds the directory to the design:

- Each key file has a block, and each block has a file.
- Each name matches the pattern of `Fugu::KeyDir`.
- Each purpose holds exactly one `current` key.
- `SHA256` names every key file, with the digest that the file has.
- The declared fingerprint of an OpenPGP key equals the computed one.

The check verifies no signature. A signature verification is the work of a
consumer install, because the site build cannot sign.

## The unit

The implementation adds one unit, `WEB-KEYS`, to `spec/web.md`, and it sets the
register row. The unit states the description blocks, the generated paths, the
copy of the manifest pair, and each rule of the check. `spec/web.md` holds no
unit today, so this is the first one.

## Work

1. `App::FuguWeb::Config`: the `keys` block and the `key` block, the accessors,
   and the key paths of the inventory.
2. `App::FuguWeb::Site`: copy the key files and the manifest pair, and generate
   each file through the Fugu modules.
3. `App::FuguWeb::Check`: each rule above.
4. `spec/web.md` and `spec/STATUS.md`: the `WEB-KEYS` unit and its row.
5. The tests: each generated file, each check, and a description with no `keys`
   block.
6. Release FuguWeb, because the publish workflow of a site installs the latest
   release.

The web pack of FuguBSD/Tooling documents the blocks in `web/CLAUDE.md`. That
work belongs to Tooling, and this plan defers it.

## Status

### What lands now

Every step above. Fugu v0.3.0 carries each module that this work calls, and no
step needs a published key.

### What waits

FuguBSD/Website waits on the release of step 6. Its `keys` block, its first key
and its rotation workflow are the next change, and they belong to that
repository.

### What this plan does not resolve

The `Drift` job of this repository fails, and it fails on `main` as well. The
org pack changed, and this repository has not synced it. A sync breaks
`make deps` here, because the `dist` entry of `deps/*.txt` names the stable URL
`releases/latest/download/Fugu.tar.gz`, which takes no digest and needs the
signify tier.

That is the deadlock: this work unblocks the key, and the key unblocks the sync.
The operator resolves it, and the two ways are:

- Pin the `dist` entry to a versioned URL, such as
  `releases/download/v0.3.0/Fugu-0.3.0.tar.gz`, and record its digest. The
  digest tier then needs no key, and this repository syncs at once. A version
  bump becomes a pull request.
- Leave the entry on the stable URL, and sync after the first key publishes.

Neither one changes the work above. This plan proceeds with the gate red, and it
states why.
