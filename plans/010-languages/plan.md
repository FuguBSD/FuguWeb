# 010 — The multi-language site

## Status

Work package 1 landed, with the languages and the text over Fugu 0.5.5. It set
WEB-SITE, WEB-KEYS and WEB-OUTPUT to `done`, and WEB-LANGUAGE and WEB-CHROME to
`partial`.

Work package 2 landed, with the links and the chrome. It set WEB-CHROME and
WEB-LINKS to `done`. The top-level `404.html` takes the base of WEB-TOP-3, so
WEB-TOP is `partial`. The sheet holds the rule above `main` and `footer`, and
WEB-STYLE-9. WEB-STYLE stays `partial`.

Work packages 4 and 5 can land now. Work packages 3 and 6 wait on work
package 4. Each work package lands as one pull request. It trims the
`Implements:` citation of each unit that it sets to `done`. The work package
that lands last deletes this plan directory.

- Implements: WEB-LANGUAGE.
- Implements: WEB-TOP.
- Implements: WEB-OUTLINE.
- Implements: WEB-STATUS.
- Implements: WEB-MANUALS.
- Implements: WEB-STYLE.

## Purpose

Issue 23 of FuguWeb lists what a site in two languages needs. A site of FuguWeb
0.10 builds one tree for each language, but the languages are an addition to a
renderer of one language. A two-letter code is the one fact about a language.
Each kind of page takes its own link form. The language links sit in the site
navigation, and the head names no translation. The renderer writes the words of
the head and the foot of a manual page in English, in each tree.

This plan rebuilds the page side of FuguWeb on one model. The specification
holds the design: D-05, D-06 and D-07, and the units that this plan cites. The
model has four parts:

1. A site is a matrix of languages and pages. The description declares each
   language with its tag, its name and its direction. Each value and each source
   of a page records the language that it comes from.
2. Text is UTF-8 at each edge, and characters inside. The build decodes each
   value, each source and each output of a renderer, and it encodes each page
   that it writes.
3. Each file of the site has one path below the site root. The writer makes each
   link relative from that path, and the check resolves each link back to it.
   The kinds of page go.
4. The build fits each body fragment to the page. It removes the frame of a
   renderer, and it takes each heading id from the default language.

The key directory, the rotation and the workflows keep their design. They change
at two points. The human page of a key directory takes the one chrome. A `keys`
name must not be the path of a tree.

## Evidence

- `Fugu::Config` trims a value with `\s`, and `use v5.34` turns on
  `unicode_strings`. The trim therefore removes a final byte 0x85 or 0xA0, which
  is the last byte of a UTF-8 character. A read of `name = voilà` gives the
  bytes `766f696cc3`. `name = 简体中文` reads correctly by chance.
- lowdown(1) makes each heading id from the Latin letters of the heading.
  `## 安装` gets `id="section"`, and `## 面向 CTO` gets `id="cto"`. mandoc(1)
  writes no id for a section heading with no ASCII letter.
- mandoc(1) writes each section heading as an `h1`, and the head and the foot as
  two tables. It writes each character outside ASCII as a numeric reference.
- [Config.pm](../../lib/App/FuguWeb/Config.pm) calls `setting_names` nowhere. A
  misspelled setting of a default block passes in silence.
- `%KIND` of [Page.pm](../../lib/App/FuguWeb/Page.pm) holds three kinds of page,
  each with its own link step. [Check.pm](../../lib/App/FuguWeb/Check.pm)
  matches the exact bytes of each form, so the two modules change together.
- `_tree_dir` of [Site.pm](../../lib/App/FuguWeb/Site.pm) owns each top-level
  directory of two letters. A tag such as `zh-Hans` breaks the prune and the
  clean.
- Site.pm runs git(1) for the date of each POD page. The date shows in the foot
  of the page alone.
- `Fugu::Signify` holds `parse_manifest` and `write_manifest`. `write_manifest`
  refuses a path with ASCII white space, a parenthesis or a character above 255.
  Within this limit, the record of WEB-STATUS-1 needs no new code in Fugu.

## The architecture

| Module                   | After this plan                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `App::FuguWeb`           | The constants, the escape functions over characters, and `decode` and `encode` for UTF-8 at each edge.     |
| `App::FuguWeb::Language` | New. One declared language: the tag, the name, the direction, the tree path, the site name and the footer. |
| `App::FuguWeb::Config`   | Reads the description into the model. Each value records its language. The key reader stays.               |
| `App::FuguWeb::Fragment` | New. The outline, the heading ids, the fit of the mandoc fragment, and the fit of a 404 body.              |
| `App::FuguWeb::Page`     | The one chrome. It takes the path of the page, and it holds no kind of page.                               |
| `App::FuguWeb::Site`     | Renders the default language first, then each other language against its outlines.                         |
| `App::FuguWeb::Status`   | New. The record, `fuguweb status` and `fuguweb translated`.                                                |
| `App::FuguWeb::Check`    | Resolves each link from the path of its page, and holds the chrome of each language.                       |

`Index`, `Manual`, `Render`, `Keys` and `Rotate` keep their roles.

## The clean break

Each work package breaks the old form, and it keeps no path for it. The few
users of FuguWeb migrate by hand.

- A work package deletes the code, the tests and the documentation of the form
  that it replaces, in the same change.
- The build accepts no old form, and it writes no migration message. An old
  setting fails as an unknown setting, per WEB-SITE-4.
- No constant, option, setting or function stays for an old caller.

## The change

### Work package 1: the languages and the text

1. Pin the release of Fugu with the fix of `Fugu::Config` in each manifest of
   [deps/](../../deps/).
2. In [FuguWeb.pm](../../lib/App/FuguWeb.pm), add `decode` and `encode`. A
   decode refuses bytes that are not UTF-8, and its message names the file. The
   escape functions read characters. Delete `DEFAULT_LANGUAGE` and
   `LANGUAGE_CODE`.
3. Add `App::FuguWeb::Language` with its POD sidecar and a test. It holds the
   tag rule of WEB-LANGUAGE-1 and the values of WEB-LANGUAGE-2 and
   WEB-LANGUAGE-3.
4. In [Config.pm](../../lib/App/FuguWeb/Config.pm), read the `language` blocks,
   `url` and `footer`. Read a translation block by its declared tag. Give each
   value its language, and read each value through `decode`. Refuse each block
   type and each setting that fuguweb(1) does not document. Refuse each source
   whose path from the project root holds ASCII white space or a parenthesis.
   Delete the message for an `anchor` setting. Delete the convention of
   `<code>/footer.body.html`.
5. In [Site.pm](../../lib/App/FuguWeb/Site.pm), write each tree and each staging
   directory below the tree path. Make the prune and the clean own the declared
   trees alone. Read each source through `decode`, and write each page through
   `encode`.
6. In [Page.pm](../../lib/App/FuguWeb/Page.pm),
   [Index.pm](../../lib/App/FuguWeb/Index.pm) and
   [Keys.pm](../../lib/App/FuguWeb/Keys.pm), write `lang` and `dir` on the
   `html` element and on each element of WEB-LANGUAGE-11. The key page is a page
   of `en`, per WEB-CHROME-8.
7. In [Check.pm](../../lib/App/FuguWeb/Check.pm), hold each tree page to the
   `lang` and the `dir` of its tree. Walk each tree from the entry page below
   its path, per WEB-LANGUAGE-13. Delete each use of the two constants of
   step 2.
8. In [Manual.pm](../../lib/App/FuguWeb/Manual.pm), take the language of each
   manual from the model. Delete each use of `DEFAULT_LANGUAGE`.
9. In [Render.pm](../../lib/App/FuguWeb/Render.pm), read each output of a
   renderer through `decode`, per WEB-SITE-5.
10. In Keys.pm and Config.pm, refuse a `keys` name that is the path of a
    declared tree.
11. In the starter of `fuguweb init` and in the [.fuguwebrc](../../.fuguwebrc)
    of this project, write `url` and `footer`.
12. In lib/, t/ and man/, point each citation of a rule of the retired unit
    WEB-LANG to the rule that replaces it. Delete each citation that no rule
    replaces.
13. Update [config.t](../../t/fuguweb/config.t),
    [site.t](../../t/fuguweb/site.t), [page.t](../../t/fuguweb/page.t),
    [index.t](../../t/fuguweb/index.t), [keys.t](../../t/fuguweb/keys.t),
    [check.t](../../t/fuguweb/check.t), [manual.t](../../t/fuguweb/manual.t) and
    [render.t](../../t/fuguweb/render.t). Add a fixture of three languages:
    `en`, `zh-Hans` and one of `dir = rtl`. Add a value that ends in `à`.
14. Update [fuguweb.1](../../man/fuguweb/fuguweb.1) and each POD sidecar that
    changes.
15. In [STATUS.md](../../spec/STATUS.md), set WEB-SITE, WEB-KEYS and WEB-OUTPUT
    to `done`. Set WEB-LANGUAGE to `partial`, with WEB-LANGUAGE-11 and
    WEB-LANGUAGE-12 absent. WEB-LANGUAGE-11 waits on the `section` of the
    top-level `404.html`, and WEB-LANGUAGE-12 on the fit of the mandoc fragment.

### Work package 2: the links and the chrome

1. Rewrite Page.pm. A page takes its path below the site root, and one function
   makes each link relative from it. Write the `head` of WEB-CHROME-1, the
   `header` of WEB-CHROME-2, the `nav` list and the `footer`. Delete `%KIND`,
   `MIDDLE_DOT` and the chrome `hr`.
2. Write the human page of each key directory through the same Page, with its
   own path, per WEB-CHROME-8.
3. Rewrite the link checks of Check.pm. Resolve each relative link from the path
   of its page. Hold the list of the languages, `aria-current`, the `head`
   links, and a chrome with no class and no text separator.
4. In [style.css](../../share/fuguweb/style.css), draw the rule of WEB-STYLE-5
   above `main` and above `footer`. Draw the two lists and their separators per
   WEB-STYLE-9.
5. Update page.t, check.t, keys.t and [t/web/site.t](../../t/web/site.t).
6. Update fuguweb.1 and Page.pod.
7. In STATUS.md, set WEB-CHROME and WEB-LINKS to `done`.

### Work package 3: the top-level pages

1. In Site.pm, write the forward page per WEB-TOP-1 and WEB-TOP-2.
2. Write the top-level `404.html` per WEB-TOP-3, WEB-TOP-4 and WEB-TOP-5. Fit
   each body with Fragment.pm, per WEB-TOP-6.
3. In Check.pm, hold the two pages to WEB-TOP.
4. Update site.t, check.t and fuguweb.1.
5. In STATUS.md, set WEB-TOP and WEB-LANGUAGE to `done`.

### Work package 4: the fit of each fragment

1. Add `App::FuguWeb::Fragment` with its POD sidecar and a test. It reads the
   outline of a fragment, and it sets each heading id by position. It fits a
   mandoc fragment per WEB-MANUALS-9, WEB-MANUALS-10 and WEB-MANUALS-11. It fits
   a body of the top-level `404.html` per WEB-TOP-6.
2. In Site.pm, render the default language first, and keep the outline of each
   default page. Hold each page of another language to that outline, and give it
   the ids.
3. Delete the `mandoc_os` setting and the `-I os=` option. Delete the pins of
   `--center` and `--release`, and the git(1) date of a POD page. Each one feeds
   the head or the foot alone.
4. In style.css, delete the rules of the head and the foot of a manual page.
   Move the rules of `h1.Sh` and `h2.Ss` to `h2.Sh` and `h3.Ss`.
5. In Check.pm, hold each heading id per WEB-OUTLINE-3.
6. Update [render.t](../../t/fuguweb/render.t), site.t, check.t, t/web/site.t
   and fuguweb.1.
7. In STATUS.md, set WEB-OUTLINE and WEB-MANUALS to `done`. Keep WEB-LANGUAGE
   `partial`, with WEB-LANGUAGE-11 as the one absent rule.

### Work package 5: the translation status

1. Add `App::FuguWeb::Status` with its POD sidecar and a test. Read and write
   the record with the manifest functions of `Fugu::Signify`.
2. In [CLI.pm](../../lib/App/FuguWeb/CLI.pm), add the verbs `status` and
   `translated`.
3. Update [cli.t](../../t/fuguweb/cli.t) and fuguweb.1.
4. In STATUS.md, set WEB-STATUS to `done`.

### Work package 6: the scripts and the directions

1. In style.css, add the font stacks of WEB-STYLE-10 and the Han rules of
   WEB-STYLE-11. Replace each physical property with its logical one, per
   WEB-STYLE-12.
2. Update t/web/site.t: hold each stack, the Han rules, and no physical
   property.
3. In STATUS.md, set WEB-STYLE to `done`.

## The release and the sites

- The release after the last work package breaks the description, so it takes
  the next minor version.

- Each site migrates by hand after the release. It adds its `url` and its
  `footer`. A site of two languages adds its `language` blocks, and it writes
  the tag in each translation block. Its trees move, for example from `zh/` to
  `zh-hans/`.

## What this plan does not do

- It selects no language from `Accept-Language`. A host that can select one does
  it with its own rule.
- It translates no key page, per WEB-LANGUAGE-12, and it writes no sitemap.
- It takes no variant subtag and no extension subtag in a tag.
- It changes no rule of the rotation, the trust, the certificate or the
  workflows.
- It keeps the classes of mandoc, per D-04.
- It moves no key reader out of Config.pm.
