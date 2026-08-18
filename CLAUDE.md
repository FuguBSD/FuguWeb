# CLAUDE.md

> **CRITICAL: Write all output and all artifacts in ASD-STE100 Simplified
> Technical English.** This rule applies to the README, `INSTALL.md`, man pages,
> `.pod` sidecars, code comments, commit messages, and chat replies. Use the
> active voice and the approved words. Keep each instruction shorter than 20
> words and each descriptive sentence shorter than 25 words. Write one
> instruction in each sentence. Do not change technical names, commands, or code
> examples.

FuguWeb builds a documentation website for a Perl project from mdoc(7) manuals,
`.pod` sidecars and Markdown, driven by `bin/fuguweb` and a `.fuguwebrc` site
description at the project root. There is no templating language and no
JavaScript: the tool runs `mandoc`, `lowdown` and `pod2man`, and wraps each
result in one shared chrome.

The repo holds one Perl namespace, `App::FuguWeb::` (`lib/App/FuguWeb/`), with
`lib/App/FuguWeb.pm` as the lead module of the App-FuguWeb distribution.

The dependency direction is one way. `App::FuguWeb` uses the installed `Fugu::`
library and core Perl, and nothing else: zero CPAN dependencies is a stated
contract. It never uses `Protocol::` and never uses another `App::` namespace: a
sibling application is not a library. `t/fuguweb/boundary.t` enforces all of it.

Fugu installs from its latest GitHub release: the `dist` line of the `deps/`
manifests fetches `releases/latest/download/Fugu.tar.gz` and installs it with
cpanm. `make deps` does this for CI and for a laptop alike.

## Commands

```sh
make check          # lint + test + tidy; MUST pass before every commit
make test           # prove -l -v t/{fuguweb,scripts,ci}/*.t
prove -l t/fuguweb/foo.t   # run a single test file
make lint           # Perl::Critic, severity 4

make tidy           # check perltidy formatting
make tidy-fix       # auto-fix Perl formatting
make prettier       # check Markdown/JSON/YAML formatting
make prettier-fix   # auto-fix Markdown/JSON/YAML
make deps           # install runtime dependencies (Fugu, mandoc, lowdown)
make deps-test      # runtime + test dependencies
make deps-develop   # all dependencies (none beyond test today)
make dist           # build the release tarball, a standard Perl distribution
```

## Layout

- `bin/fuguweb` — the CLI entry point, over `App::FuguWeb::CLI`
- `lib/App/FuguWeb/` — the modules, one concern each: the CLI (`CLI.pm`), the
  site description (`Config.pm`), the chrome (`Page.pm`), the manual index
  (`Manual.pm`, `Index.pm`), the external renderers (`Render.pm`), the build
  (`Site.pm`), and the checks (`Check.pm`). Every module has a `.pod` sidecar —
  never inline POD
- `man/fuguweb/fuguweb.1` — the mdoc(7) reference for the tool
- `share/fuguweb/style.css` — the base stylesheet. `Site.pm` resolves it with
  `Fugu::File->share_path`, passing `from => __FILE__` and
  `dist => 'App-FuguWeb'`, so a checkout and an installed distribution both work
- `t/fuguweb/` — unit tests; `t/scripts/`, `t/ci/` — tooling tests, named after
  what they drive
- `deps/` — per-OS dependency manifests; `scripts/` — the dependency, download
  and dist helpers (`deps`, `ftp`, `dist`)

External programs: `mandoc`, `lowdown`, and `pod2man`.

## Coding style

OpenBSD style(9): 8-character tabs, continuation lines indent 4 spaces.
Formatting is enforced by `make tidy` and `make lint` — run `make tidy-fix`
rather than hand-formatting. `.perlcriticrc` deliberately relaxes many rules to
match OpenBSD style; do not "fix" code toward generic Perl::Critic defaults.

Rules the tools cannot enforce:

- Always `use v5.36` (enables strict, warnings, say, signatures) — the only
  exception is `scripts/deps`, see Dependencies
- Object-oriented style with signatures; object is `$self`; internal methods
  prefixed with `_`; do not name unused parameters: `sub foo($, $) { }`
- Function brace on its own line, control-structure brace on the same line:

```perl
sub method($self, $param)
{
	if ($condition) {
		...
	}
	return $result;
}
```

- Explicit `return` except for no-return or constant methods; omit parens on
  zero-argument method calls: `$object->width`
- Inheritance via `our @ISA` (not `use parent`); no multiple inheritance;
  multiple related packages per file are fine; constants via `use constant`
- New files start with the `# ex:ts=8 sw=4:` modeline and ISC copyright header —
  copy from an existing file in `lib/`
- `Class->new`, never indirect object notation; code refs always with
  parentheses (except delegation); no old-style prototypes unless creating
  syntax
- Simple string operations over regex where they suffice; `wantarray()` only as
  an optimization, never to change semantics

## Error handling and security

- Return `undef` (bare `return`) for recoverable errors, `die` for programming
  errors; never use `eval` for flow control
- Never ignore return values of system calls:
  `open my $fh, '<', $file or do { warn "..."; return; };`
- Fail cleanly: diagnose invalid input in a human-readable message, never a
  stack trace; leave no partial files, orphaned processes, or corrupt state
  behind; make repeatable operations truly idempotent

## Simplicity

- Delete old code paths outright; never keep an alias, a bridge, or a migration.
- Do not keep test-only API. Delete a sub or option that only tests use,
  together with its test.
- Validate each input once, at its boundary. Do not check the same invariant
  again downstream.

## Testing

- Unit tests use `Test::More` with `done_testing()`; they skip gracefully when a
  dependency is unavailable (`plan skip_all => ...`); mirror an existing test in
  `t/fuguweb/` when adding one
- Be resilient to timing variations
- Every feature needs tests
- The tests need the Fugu library on `@INC`; a local build of the sibling
  checkout works too: `cpanm --local-lib=local ../Fugu/build/Fugu-*.tar.gz`

## Documentation

Every fact lives in exactly one place; everything else points to it:

- `README.md` — intro and quick start; `INSTALL.md` — install and setup;
  `man/fuguweb/fuguweb.1` — the authoritative tool reference
- The API of every module — its sidecar `.pod`, never inline POD
- A new `lib/` module needs a `.pod` sidecar and a test
- No `README.md` anywhere except the repository root
- Update the relevant documentation with any change in behavior, options, or
  configuration

## Dependencies

`deps/{OpenBSD,Linux,Darwin}.txt` are authoritative, installed by `make deps`
via `scripts/deps`; one line each, `<environment> <type> <name>`, where
`<environment>` is `runtime`, `test`, or `develop` and `<type>` is `pkg`,
`dist`, or `cpan`. A `dist` line names a release-asset URL, and `scripts/deps`
installs the tarball with cpanm — this is how Fugu arrives.

`scripts/deps` is the one exception to `use v5.36`: it runs before anything is
installed, and macOS still ships perl 5.34. It uses `use v5.34` plus explicit
`use warnings` and core modules only. Do not "fix" it up to 5.36.

- Justify the need first: prefer base-system Perl, and `require` optional
  dependencies so they stay optional
- Prefer `pkg` over `cpan` — OS packages are vetted, binary, and upgraded with
  the system (on OpenBSD the native `p5-*` packages)
- Add the line to every platform manifest that applies, keep the `cpanfile` in
  sync, then verify with `make deps` and commit with the `build` type

## Releases

Releases use semantic versioning: the tag is `v<MAJOR>.<MINOR>.<PATCH>` and the
dist version drops the `v`. There is no VERSION file and no `$VERSION` in a
module — the version derives from the latest `v*` tag. `make dist` builds a
standard Perl distribution tarball (`scripts/dist` writes its `Makefile.PL` and
`MANIFEST` into the staged tree only).

The Build workflow builds the dist on every merged commit and keeps it as a
workflow artifact — it releases nothing. A release is deliberate: push a
`v<MAJOR>.<MINOR>.<PATCH>` tag (`git tag v0.1.0 && git push origin v0.1.0`) and
the Release workflow tests, builds once, and publishes the one tarball in
separate steps: to GitHub Releases — under its versioned name and as
`App-FuguWeb.tar.gz`, the stable asset that
`releases/latest/download/App-FuguWeb.tar.gz` serves to the consumers — and to
PAUSE, with the `PAUSE_USERNAME` and `PAUSE_PASSWORD` secrets from the `release`
environment.

CI uses no third-party action: GitHub's own `actions/`, the canonical FuguBSD
actions in FuguBSD/Fugu, and local paths only. `t/ci/workflows.t` enforces it.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):
`<type>(<scope>): <description>` with types `feat`, `fix`, `docs`, `style`,
`refactor`, `perf`, `test`, `build`, `ci`, `chore` and module scopes such as
`cli`, `config`, `check`, `index`, `manual`, `page`, `render`, `site`. Breaking
changes take `!` or a `BREAKING CHANGE:` footer.

Always run `make check` before committing; fix formatting failures with
`make tidy-fix`. Group unrelated changes into separate commits rather than one
sweeping commit.

## Gotchas

- Use `explore/` (gitignored) for scratch scripts and experiments, never `/tmp`
- Audit findings go to `SCRATCHPAD-<N>.md` files (gitignored)
