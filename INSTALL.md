# Install FuguWeb

FuguWeb runs on Perl v5.36 or later over the Fugu library, with `mandoc` and
`lowdown` as the external renderers (`pod2man` ships with perl). There are two
install flows: from a checkout with make, and from a release tarball with cpanm.

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

## From a release tarball

Every release carries a standard Perl distribution tarball. Install the latest
Fugu release first, then FuguWeb; the stable URLs always serve the latest
releases:

```sh
cpanm --notest https://github.com/FuguBSD/Fugu/releases/latest/download/Fugu.tar.gz
cpanm --notest https://github.com/FuguBSD/FuguWeb/releases/latest/download/App-FuguWeb.tar.gz
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
