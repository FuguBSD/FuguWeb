# 009 — The language tree

## Status

Work package 1 landed: every page of the description sits in the tree of `en`.
Work package 2 can land now, as one pull request.

- Implements: WEB-LANG.
- Extends: WEB-MANUALS.

## Purpose

Every page of the description sits in the tree of the default language, below
`/en/`. Every string of the description exists in one language, and the code
also writes English of its own. [Index.pm](../../lib/App/FuguWeb/Index.pm)
writes the opening paragraph of the manual index, and
[Keys.pm](../../lib/App/FuguWeb/Keys.pm) writes the human page of the key
directory.

A translation is a block with the language code in front of the block name, for
example `page de "index.html" { title = Start; body = de/index.body.html }` and
`manuals de commands { heading = Befehle; dir = man/de/fuguweb }`. The grammar
of `Fugu::Config` keeps every argument of a block header in order today, so the
description needs no new grammar. One translation block anywhere adds a whole
tree. Each page of that tree without a translation shows the default source,
with `lang="en"` on its body.

A block name is an identifier, and prose is per language. A group block name
therefore becomes its anchor word, and the heading becomes a `heading` setting.
The `anchor` setting goes. The index page takes a `body` that opens it, and the
renderer writes no prose of its own.

## Evidence

- `Fugu::Config` keeps the arguments of a block header in order, and indexes
  each block by its last argument. The comment at
  `../Fugu/lib/Fugu/Config.pm:44-50` states this. A translation block therefore
  parses today, and `blocks('page')` returns the default and the translations in
  file order.
- The renderer holds hard-coded English in three places. The opening of the
  manual index sits at `Index.pm:91-96`. The heading and the column heads of the
  key page sit at `Keys.pm:1351-1357`. The center text `Perl Library Manual`
  sits at `Render.pm:50`.
- [Check.pm](../../lib/App/FuguWeb/Check.pm) refuses each root-absolute href but
  the `base` of the top-level `404.html`. The language links therefore stay
  relative: `../<code>/<page>`.

## The change

### Work package 2: the translations

1. Land the rule text of WEB-MANUALS with the code. Make WEB-MANUALS-6 take the
   heading text from `heading` and the anchor from the group name. Add a rule to
   WEB-MANUALS for the group name. A group name must be one word of lowercase
   letters, digits and hyphens. Two groups must not share one, and each default
   group block must take a `heading`. Add a second rule to WEB-MANUALS for the
   index body. An `index` page can take a `body`, which opens the page below its
   heading. The index writes no opening of its own.
2. In [Config.pm](../../lib/App/FuguWeb/Config.pm), read the translation blocks
   of `page`, `nav`, `manuals` and `modules` from the block arguments. Validate
   the code shape, and reject `en`. Reject an orphan translation, a duplicate,
   and a setting outside the permitted set. Rename the group block name to the
   anchor word, and add `heading`. Drop `anchor`. Let an `index` page take
   `body`. Make `languages` return `en` plus each translated code.
3. In `Config::Group` and [Manual.pm](../../lib/App/FuguWeb/Manual.pm), resolve
   the source of each manual per language with the mirror rule and the namesake
   error. Take the page name from the default source.
4. In [Site.pm](../../lib/App/FuguWeb/Site.pm) and
   [Render.pm](../../lib/App/FuguWeb/Render.pm), stage and render each language
   from its own source. Mirror the `modules` umbrella `<dir>.pod` too.
5. In [Page.pm](../../lib/App/FuguWeb/Page.pm), write the body marker
   `lang="en"` on a fallback page. Write the language links with `hreflang`, and
   the footer fragment of the language.
6. In [Index.pm](../../lib/App/FuguWeb/Index.pm), drop the hard-coded opening
   and the `manuals.body.html` convention. Write the heading from the title,
   then the body of the page, then the groups.
7. In [CLI.pm](../../lib/App/FuguWeb/CLI.pm), update the starter description, if
   it names a group.
8. Update the tests. Add a two-language fixture to
   [site.t](../../t/fuguweb/site.t) and [config.t](../../t/fuguweb/config.t). It
   holds the tree pair, the fallback marker, the mirror error, the language
   links, and the one-language site with no link. It holds each rejection of
   WEB-LANG-1, WEB-LANG-2 and WEB-LANG-4. [index.t](../../t/fuguweb/index.t)
   holds the heading from `heading`, the body, and no opening of its own.
   [page.t](../../t/fuguweb/page.t) follows.
9. In [.fuguwebrc](../../.fuguwebrc) of this project, write
   `manuals commands { heading = Commands ... }` and
   `modules modules { heading = Modules ... }`, without `anchor`.
10. Update the documentation. [fuguweb.1](../../man/fuguweb/fuguweb.1) and
    [Config.pod](../../lib/App/FuguWeb/Config.pod) describe the translation
    block, `heading`, the group name, the index `body` and the footer
    convention. [Index.pod](../../lib/App/FuguWeb/Index.pod) follows.
11. In [STATUS.md](../../spec/STATUS.md), move WEB-LANG to `done`, and delete
    this plan directory.

## What this plan does not do

- It translates no key page and no `site` name. The key page is a page of the
  default language.
- It moves no key directory URL. It changes nothing of the rotation, the trust
  rules, `security.txt` or the workflows.
- It adds no `<link rel="alternate">`, no sitemap and no canonical URL.
- It takes no language subtag such as `pt-BR`. A code is two letters.
- It keeps the center text `Perl Library Manual` of a POD page in every
  language.
- It changes nothing in the Fugu library.
- It changes no org site. Each site renames its group blocks and republishes
  after a release of FuguWeb, in its own change.
