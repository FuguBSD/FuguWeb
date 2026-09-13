# Install FuguWeb

FuguWeb runs on Perl v5.36 or later over the Fugu library, with `mandoc` and
`lowdown` as the external renderers (`pod2man` ships with perl). There are two
install flows: from a checkout with make, and from CPAN with cpanm.

The key verbs `fuguweb mint-key`, `fuguweb import-key` and `fuguweb promote-key`
each need the command of their key type. `signify(1)` signs a signify key,
`gpg(1)` signs an OpenPGP key, and `openssl(1)` signs a certificate.
`deps/Darwin.txt` and `deps/Linux.txt` name a package for each one.
`deps/OpenBSD.txt` names a package for none of the three, so `make deps`
installs no key command there. That manifest states that the base system holds
`signify(1)`. It names no package for `gpg(1)`, so an operator who signs an
OpenPGP key on OpenBSD installs that command first. A build signs nothing and
verifies nothing, so it runs without the three. A check verifies each binding. A
signify binding needs no command, and a binding of another type needs the
command of that type.

## From a checkout

```sh
git clone https://github.com/FuguBSD/FuguWeb.git
cd FuguWeb
make deps
doas make install
```

`make deps` installs the latest
[Fugu release](https://github.com/FuguBSD/Fugu/releases/latest) and the renderer
packages. `make install` copies `bin/fuguweb`, the modules, the manual, and the
stylesheet. `make uninstall` removes them.

## From CPAN

Every release goes to CPAN as the
[App-FuguWeb](https://metacpan.org/dist/App-FuguWeb) distribution. The
distribution does not name Fugu as a prerequisite, so name both:

```sh
cpanm --notest Fugu App::FuguWeb
```

The cpanm flow installs the modules, the binary, and the stylesheet. The mdoc(7)
manual ships in the tarball but installs through the make flow. The `mandoc` and
`lowdown` packages come from the OS package manager either way (on OpenBSD,
`mandoc` is in the base system).

## Set up a project

Write a `.fuguwebrc` at the project root, or let the tool write a starter:

```sh
fuguweb init
fuguweb build --out web/build
```

## Verify

```sh
fuguweb check --out web/build
```
