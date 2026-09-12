# 007 — Several key directories

## Status

Proposed. It can land now. Nothing waits on it, and it waits on nothing.

Extends: WEB-KEYS. Extends: WEB-OUTPUT. Extends: WEB-ROTATE.

## Purpose

A site publishes one key directory. A publisher that keeps two trust domains,
for example the keys of the organization and the keys of one project, needs two
sites. Two sites cost two repositories and two publish workflows.

This plan lets a description hold several `keys` blocks. Each block names its
own directory, its own organization word, and its own root. The site-level files
stay single: one `security.txt`, and one Web Key Directory that gathers every
address.

## Evidence

`App::FuguWeb::Config` reads one `keys` block and refuses a second. Every reader
of the block asks `keys_dir`, `keys_org`, `keys_url` and `site_keys`, so the
change touches one accessor set. `App::FuguWeb::Keys->shaped` tests one
directory name, and the clean and the prune read that one answer.

## The rule changes

### WEB-KEYS

- WEB-KEYS-1 takes several `keys` blocks. Each block names one directory, and
  two blocks must not name one directory.
- WEB-KEYS-3 lets one block alone name `contact` and `expires`. A second block
  that names them is an error, because the site holds one `security.txt`.
- WEB-KEYS-14 gathers the keys of one address across every directory into one
  file, in publication order.
- WEB-KEYS-15 reads the `current` OpenPGP key of the block that names the
  contact.
- WEB-KEYS-30 holds each block name against the inventory and against each other
  block.

### WEB-OUTPUT

- WEB-OUTPUT-10 and WEB-OUTPUT-12 read each declared directory. A directory that
  the description dropped keeps its files, and the check reports them, per
  WEB-OUTPUT-4.

### WEB-ROTATE

- WEB-ROTATE-21 takes `--dir` as the selector of the directory. A description
  with one block needs none, and one with several refuses a step without it.

## The change

1. `lib/App/FuguWeb/Config.pm` holds a list of key directories, and each
   accessor takes the directory name.
2. `lib/App/FuguWeb/Keys.pm` takes one directory at a time, and the Web Key
   Directory and `security.txt` read the union.
3. `lib/App/FuguWeb/Site.pm` builds each directory, and `shaped` reads each
   declared name.
4. `lib/App/FuguWeb/Rotate.pm` and `CLI.pm` select the directory with `--dir`.
5. `man/fuguweb/fuguweb.1` describes the second block.
6. `t/fuguweb/config.t`, `keys.t` and `site.t` cover two directories, and the
   refusals above.
7. This plan directory goes in the same change.

## What this plan does not do

It shares no root between two directories. Each directory holds its own root,
per D-02, and a binding never crosses a directory.
