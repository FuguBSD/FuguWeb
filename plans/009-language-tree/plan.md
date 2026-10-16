# 009 — The language tree

## Status

Proposed. Work package 1 can land now. Work package 2 waits on work package 1.
Each package is one pull request.

- Implements: WEB-LANG.
- Extends: WEB-MANUALS.
- Extends: WEB-OUTPUT.
- Extends: WEB-KEYS.

## Purpose

Today the build writes one flat directory. One `lang` setting gives every page
the same `<html lang>`, and every string of the description exists in one
language. The code also writes English of its own.
[Index.pm](../../lib/App/FuguWeb/Index.pm) writes the opening paragraph of the
manual index, and [Keys.pm](../../lib/App/FuguWeb/Keys.pm) writes the human page
of the key directory.

In the new design every page sits under `/<code>/`, so `/` becomes `/en/` and
`/manuals.html` becomes `/en/manuals.html`. A translation is a block with the
language code in front of the block name, for example
`page de "index.html" { title = Start; body = de/index.body.html }` and
`manuals de commands { heading = Befehle; dir = man/de/fuguweb }`. The grammar
of `Fugu::Config` keeps every argument of a block header in order today, so the
description needs no new grammar. One translation block anywhere adds a whole
tree. Each page of that tree without a translation shows the default source,
with `lang="en"` on its body.

A block name is an identifier, and prose is per language. A group block name
therefore becomes its anchor word, and the heading becomes a `heading` setting.
The `anchor` setting goes, and the `lang` setting goes. The index page takes a
`body` that opens it, and the renderer writes no prose of its own.

Two files stay at the top level for the host. `index.html` forwards to `en/`.
The top level holds one more copy of the `404.html` page of the default
language, with `<base href="/">`. A host serves it at any path.

The key directory, the well-known tree, the stylesheet and the assets stay at
the top level. A consumer fetches each one by a fixed URL.

## Evidence

- The built site of this project holds 17 files at one level: `404.html`,
  `App::FuguWeb.3p.html`, ten `App::FuguWeb::*.3p.html` module pages,
  `fuguweb.1.html`, `index.html`, `manuals.html`, `robots.txt` and `style.css`.
- `Fugu::Config` keeps the arguments of a block header in order, and indexes
  each block by its last argument. The comment at
  `../Fugu/lib/Fugu/Config.pm:44-50` states this. A translation block therefore
  parses today, and `blocks('page')` returns the default and the translations in
  file order.
- `Config.pm:430` reads the `lang` setting with the default `en`, and
  `Page.pm:98,105` writes it. One value serves the whole site.
- The renderer holds hard-coded English in three places. The opening of the
  manual index sits at `Index.pm:91-96`. The heading and the column heads of the
  key page sit at `Keys.pm:1350-1356`. The center text `Perl Library Manual`
  sits at `Render.pm:50`.
- `Page::_foot` (`Page.pm:169`) drops the footer when the page sits below the
  root. A relative link of the fragment resolves against the directory of the
  page. Inside a tree the fragment links resolve inside that tree, so a tree
  page can carry it. The fragment of this org holds one absolute link.
- `Check::_check_references` (`Check.pm:200-202`) refuses a root-absolute href.
  The language links and each relative link of the chrome therefore stay
  relative: `../<code>/<page>` and `<page>`.
- The body fragments of every org site hold one relative link, `manuals.html`,
  and no other. They work inside a tree unchanged. The Website repository links
  each project site at its root, and the forward page keeps those links alive.
- `Site::_owns` (`Site.pm:285-291`) owns any top-level name. The first build of
  the new layout therefore removes every page of the old flat layout on its own.
- A static host serves `404.html` of the publishing root for every missing path.
  GitHub Pages, Netlify and Cloudflare Pages all do this.

## The change

### Work package 1: the tree of the default language

Every page moves under `/en/`, and no translation lands yet.

1. Land the rule text of the extended units with the code. Let WEB-OUTPUT-1
   permit a file one level below a language tree. Let WEB-OUTPUT-5 permit the
   clean to remove a directory whose name has the shape of a language code. Add
   to WEB-OUTPUT-10 the shape "a plain file one level below a directory whose
   name is a language code". Make WEB-OUTPUT-14 hold one flat directory for each
   language in the staging directory. Add a rule to WEB-KEYS: the renderer must
   reject a `keys` name of two lowercase letters. Such a name would take the
   place of a tree.
2. In [Config.pm](../../lib/App/FuguWeb/Config.pm), drop the `lang` setting. Add
   `languages`, which returns `en` for now. Make `inventory` name
   `<code>/<page>` for each page of each language. Add the top-level
   `index.html`, the stylesheet, the assets, the key paths and the well-known
   tree. Add the top-level copy of `404.html` when the description holds that
   page. Reject a `keys` name of two lowercase letters.
3. In [Site.pm](../../lib/App/FuguWeb/Site.pm), write each page into its tree.
   Write the top-level `index.html` with one meta refresh to `en/<entry>` and
   one link to it. Write the top-level copy of `404.html` with its `base`. Stage
   into `.man/<code>/`. Extend `_owns`, `_stranger`, `_key_dir`, the prune and
   the clean with the tree shape.
4. In [Page.pm](../../lib/App/FuguWeb/Page.pm), take the language of the page.
   On a tree page, write each relative link of the chrome as `<page>`. On the
   key page, write each relative link of the chrome as `../en/<page>`. On the
   top-level `404.html`, write each relative link of the chrome as `en/<page>`.
   Write an absolute URL and a fragment unchanged, per WEB-LANG-15. Link the
   stylesheet as `../style.css` from a tree page and from the key page, and as
   `style.css` from the top-level `404.html`. Carry the footer on every tree
   page and on no other page. The discriminator changes from "base is empty" to
   "in a tree".
5. In [Keys.pm](../../lib/App/FuguWeb/Keys.pm), keep the human page at
   `<dir>/index.html`, with `lang="en"`. Point each relative link of the chrome
   into `../en/`, and link the stylesheet as `../style.css`. Carry no footer.
6. In [Check.pm](../../lib/App/FuguWeb/Check.pm), read the new inventory. Walk
   the reachability from `<code>/<entry>` for each language, and walk none for
   the top-level pages. Hold each tree page to the `lang` of its tree. Hold each
   relative link of the chrome to the form of its kind of page, per WEB-LANG-15.
   Accept the `base` href of the top-level `404.html` as the one root-absolute
   href. Hold the forward page to the shape of WEB-LANG-8, and to no nav.
7. Update the tests. [config.t](../../t/fuguweb/config.t) drops the `lang` cases
   and takes the new inventory. [page.t](../../t/fuguweb/page.t) holds the exact
   chrome. [site.t](../../t/fuguweb/site.t) holds the tree listing, the forward
   page, the top-level copy of `404.html` and the prune of a stale tree.
   [check.t](../../t/fuguweb/check.t) holds the three link forms of the chrome
   and an absolute nav URL. It holds the accepted `base` href, the forward page
   shape, and the refusal of any other root-absolute href.
   [keys.t](../../t/fuguweb/keys.t) with the key page links, and
   [cli.t](../../t/fuguweb/cli.t) follow. [site.t](../../t/web/site.t) of the
   built site expects `en/index.html`, `style.css` and the forward.
8. Update the documentation. [fuguweb.1](../../man/fuguweb/fuguweb.1) and
   [Config.pod](../../lib/App/FuguWeb/Config.pod) drop `lang` and describe the
   tree. Update [Page.pod](../../lib/App/FuguWeb/Page.pod),
   [Site.pod](../../lib/App/FuguWeb/Site.pod) and
   [Check.pod](../../lib/App/FuguWeb/Check.pod) as needed, and
   [web/CLAUDE.md](../../web/CLAUDE.md) if it names the output layout.
9. In [STATUS.md](../../spec/STATUS.md), move WEB-LANG to `partial`. Name
   WEB-LANG-1, WEB-LANG-2, WEB-LANG-4, WEB-LANG-5, WEB-LANG-7, WEB-LANG-12 and
   WEB-LANG-13 as absent. Name the translation part of WEB-LANG-3 and the body
   marker of WEB-LANG-6 as absent. Trim this plan to the second package.

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
- A description with a `lang` setting gets no replacement. The setting goes.
