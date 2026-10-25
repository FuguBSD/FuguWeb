# The site renderer

FuguWeb renders one static site from the documentation of a Perl project. The
renderer reads `.fuguwebrc` at the project root, runs `mandoc`, `lowdown`, and
`pod2man`, and wraps each result in one shared chrome. The output is plain HTML
and one stylesheet: no templating language and no JavaScript.

A site is a matrix of languages and pages, and the description declares both
axes. Each page of a language takes each value and each source from the language
that holds it, and it records that language. A renderer reduces each source to
one body fragment. The build fits the fragment to the page, and the chrome wraps
it. A link inside the site names a path below the site root, and the writer
makes it relative to the page that holds it. The check reads the same model as
the build.

This document holds the units of the areas that a plan has changed. The
conventions of [index.md](index.md) apply.

<a id="web-site"></a>

## The description

`.fuguwebrc` describes the site, in the grammar of `Fugu::Config`. The
description holds the words of the default language. Each translation block
holds the words of one other language, per WEB-LANGUAGE.

- **WEB-SITE-1** — The description must take a `url`, which is the absolute URL
  of the site root. The value must start with `https://` or `http://`, and it
  must end in a solidus.
- **WEB-SITE-2** — The description must take a `site`, which is the name of the
  site in each language whose block names none, per WEB-LANGUAGE-3.
- **WEB-SITE-3** — The description can take a `footer`, which names a footer
  fragment below the source directory. The fragment is the footer of each
  language whose block names none, per WEB-LANGUAGE-3.
- **WEB-SITE-4** — The renderer must reject a block type and a setting that
  fuguweb(1) does not document. The message must name the block and the word.
- **WEB-SITE-5** — The description, each source and each output of a renderer
  must be valid UTF-8. The build must reject one that is not, and the message
  must name it.
- **WEB-SITE-6** — The renderer must reject a source whose path from the project
  root holds ASCII white space or a parenthesis. A source is a page source, a
  manual or a footer fragment, of any language. The message must name the path.
  The record of WEB-STATUS-1 takes the manifest form of `Fugu::Signify`, which
  holds neither.
- **WEB-SITE-7** — The renderer must reject a `source_dir` that names the
  project root, such as `.` or `./`. The build publishes each plain file of the
  source directory, so it would publish the record of WEB-STATUS-1.

<a id="web-language"></a>

## The languages

A `language` block declares one language of the site. The block name is the tag
of the language, and the order of the blocks is the order of the languages. The
first language is the default, per D-05. A translation is a block with the tag
in front of the block name. A page without a translation takes the source of the
default language.

- **WEB-LANGUAGE-1** — A tag must be a BCP 47 tag of RFC 5646, in its canonical
  case. The renderer must accept these subtags, in this order, and no other:

  - a language subtag of two or three lowercase ASCII letters;
  - an optional script subtag of four ASCII letters, the first one in uppercase;
  - an optional region subtag of two uppercase ASCII letters or three digits.

  `en`, `zh-Hans` and `pt-BR` are tags. The renderer must reject a tag that two
  blocks declare.

- **WEB-LANGUAGE-2** — A `language` block must take a `name`, which is the name
  of the language in that language, for example `English` or `简体中文`. It can
  take a `dir` of `ltr` or `rtl`, and the default is `ltr`.
- **WEB-LANGUAGE-3** — A `language` block can take a `site` and a `footer`. In
  that language, each one takes the place of the value of WEB-SITE-2 or
  WEB-SITE-3.
- **WEB-LANGUAGE-4** — A description with no `language` block must have the one
  language `en`. A site of one language then needs no declaration.
- **WEB-LANGUAGE-5** — The path of a tree is the tag in lowercase, so the tree
  of `zh-Hans` is `zh-hans/`. The build must write one tree for each language,
  below its path in the output. Each tree must hold the same page names.
- **WEB-LANGUAGE-6** — A translation block must take two arguments: a declared
  tag other than the default, then the name of the block that it translates. A
  `page`, a `nav`, a `manuals` and a `modules` block can take a translation. The
  renderer must reject a translation of any other tag. It must reject a
  translation of a name that no default block of its type holds. It must reject
  a second translation of one name in one language.
- **WEB-LANGUAGE-7** — A translation of a `page` block can take `title`, `body`
  and `markdown`. A translation of a `nav` block can take `label`. A translation
  of a group block can take `heading` and `dir`. The renderer must reject any
  other setting on a translation.
- **WEB-LANGUAGE-8** — A tree page of a language must take each value from its
  translation, and from the default block when the translation holds none. Each
  nav label and each group heading follow the same rule. The `site` and the
  `footer` follow it too: the language block is their translation, and the
  description is their default block.
- **WEB-LANGUAGE-9** — A manual of a language must come from the `dir` of the
  translation. It must come from the default `dir` when the translation holds no
  file of that name. A translation `dir` must mirror the default `dir`, so the
  namesake of a file is the file of the same relative path. A file of a
  translation `dir` with no namesake is an error.
- **WEB-LANGUAGE-10** — The `html` element of a page must carry the tag of its
  language as `lang`. It must carry `dir="rtl"` when that language is right to
  left.
- **WEB-LANGUAGE-11** — An element whose text comes from another language than
  the page must carry the tag of that language as `lang`. It must carry `dir`
  too when the two directions differ. The mark goes on the smallest element that
  holds the text. That element is the `main` of a body, the site link of the
  `header`, or the `footer`. It is also the link of a nav label, a part of an
  index page, or a `section` of WEB-TOP-5. The parts of an index page are its
  title, the `body` that opens it, each group heading and each manual
  description. The `main` of an index page carries no mark.
- **WEB-LANGUAGE-12** — The renderer must write no prose of its own into a tree
  page or a top-level page. Each word that a reader sees there must come from
  the description, from a source or from a fragment. The human page of a key
  directory is the one exception. Its page title, its heading and the labels of
  the fields of WEB-KEYS-13 are in English.
- **WEB-LANGUAGE-13** — The check must hold each tree page to the `lang` and the
  `dir` of its tree. It must walk the reachability of each tree from its own
  entry page, and the walk must not leave the tree. A page that takes `unlinked`
  takes no reachability check.

<a id="web-chrome"></a>

## The chrome

The chrome is the part of a page around the body fragment. It is the same in
each language, and only its words change. It holds four landmarks: the banner,
the navigation, the main part and the footer. Each one is an element of HTML5,
and the chrome carries no class, per D-04.

- **WEB-CHROME-1** — The `head` of a tree page must hold five parts, in this
  order. The parts are the charset, the viewport, the title, the links of
  WEB-CHROME-6, and the stylesheet link. The title must be the page title, an em
  dash, and the site name of the language.
- **WEB-CHROME-2** — The `header` must hold a link to the entry page of the
  tree, with the site name of the language as its text. The link must carry no
  `aria-current`. On a site of more than one language, the list of the languages
  must follow the link.
- **WEB-CHROME-3** — The list of the languages must be one `ul`, with one item
  for each language, in the order of the declaration. The link of each item must
  go to the same page in that language. Its text must be the `name` of the
  language, and it must carry the tag as `lang` and as `hreflang`. The link of
  the language of the page must carry `aria-current="page"`.
- **WEB-CHROME-4** — The `nav` must hold one `ul`, with one item for each nav
  entry, in the order of the description. The link of the current page must
  carry `aria-current="page"`. A description with no nav entry must write no
  `nav`.
- **WEB-CHROME-5** — The chrome must hold no text separator and no `hr`. The
  sheet draws each rule, per WEB-STYLE-5, and each separator, per WEB-STYLE-9.
- **WEB-CHROME-6** — Each tree page must carry one `rel="canonical"` link to
  itself in its `head`. It must carry one `rel="alternate"` link for each
  language, its own language included, with the tag as `hreflang`. The link of a
  language must go to the same page in that language. The href of each of these
  links must be the `url` of WEB-SITE-1, then the path of the target page. An
  example is `https://example.org/en/index.html`. The page must carry one more
  alternate link, with `hreflang="x-default"`, to the forward page of WEB-TOP-1.
  Its href must be the bare `url`, which serves the forward page.
- **WEB-CHROME-7** — The `footer` must hold the footer fragment of the language
  of the page, unchanged. A tree page carries the footer, and no other page
  does. A site with no footer fragment carries no `footer`.
- **WEB-CHROME-8** — The human page of a key directory must be a page of the
  language `en`, because its own words are English, per WEB-LANGUAGE-12. Its
  `html` therefore carries `lang="en"`, per WEB-LANGUAGE-10. Its chrome must
  take the site name and each nav label from the default language. When that
  language is not `en`, the site link and each nav link carry the marks of
  WEB-LANGUAGE-11. The `head` must hold four parts, in this order: the charset,
  the viewport, the title, and the stylesheet link. The title must be the
  English page title alone, so the `title` holds the words of one language. The
  `head` carries no link of WEB-CHROME-6. Its `header` must hold the site link
  of WEB-CHROME-2 alone, to the entry page of the default tree. The page must
  carry the `nav` of the default tree, per WEB-CHROME-4. It carries no footer,
  per WEB-KEYS-32.

<a id="web-links"></a>

## The links

Each file of the site has one path below the site root, for example
`zh-hans/manuals.html` or `keys/index.html`. A link inside the site names that
path, and the writer makes it relative to the page that holds it. A page of any
place then takes one link rule, and a reader can browse the output from a disk.

- **WEB-LINKS-1** — A link of the chrome to a file of the site must be relative.
  It must be the path from the directory of the page to that file. The build
  must compute it from the two paths alone.
- **WEB-LINKS-2** — A relative nav `href` of the description must name a page of
  each tree, as it resolves from the path of that tree. An absolute URL must
  pass unchanged.
- **WEB-LINKS-3** — The check must resolve each relative `href` and `src` of a
  page against the directory of the page. It must resolve against the `base` of
  the page when the page holds one. The path of the result, with no query, must
  name a file of the inventory. A fragment must name an `id` of the target page.
- **WEB-LINKS-4** — The check must reject a root-absolute href. The `base` href
  of WEB-TOP-3 is the one exception.
- **WEB-LINKS-5** — Each absolute href of WEB-CHROME-6 must be the `url` of
  WEB-SITE-1, then the path of a page of the inventory. The bare `url` is the
  one other form. The check must hold each href to these forms.

<a id="web-top"></a>

## The top-level pages

The top level of the output holds two pages for the host. A static host serves
each one at a fixed path: the site root, and each path that no file answers.
Neither page belongs to a tree, so each one links every tree. A static host
cannot select a language for the reader, and D-01 bars a script. The forward
page therefore goes to the default tree.

- **WEB-TOP-1** — The build must write the forward page, `index.html` at the top
  level. It must forward to the entry page of the default tree with a meta
  refresh, and it must load nothing, per D-01. Its `head` must hold four parts
  alone, in this order: the charset, the meta refresh, the title, and the links
  of WEB-CHROME-6. It is a page of the default language, and its title must be
  the site name of that language.
- **WEB-TOP-2** — On a site of more than one language, the body of the forward
  page must hold the list of WEB-CHROME-3. The list must carry no
  `aria-current`, and each link must go to the entry page of its language. On a
  site of one language, the body must hold one link to the entry page, with the
  site name as its text. The canonical link of the page must be the bare `url`
  of WEB-SITE-1. Each alternate link of a language must go to the entry page of
  that language.
- **WEB-TOP-3** — When the description holds the page `404.html`, the build must
  write one more `404.html` at the top level. A host serves the page at each
  path that no file answers. Its `head` must hold five parts, in this order: the
  charset, the viewport, a `base`, the title, and the stylesheet link. The
  `base` must come before each element that holds a URL. Its href is the path of
  the `url` of WEB-SITE-1, so each relative link of the page resolves from the
  site root. The `head` carries no link of WEB-CHROME-6.
- **WEB-TOP-4** — The top-level `404.html` must be a page of the default
  language. Its title must be the title of the `404.html` of the default tree.
  Its `header` must hold the site link of WEB-CHROME-2, to the entry page of the
  default tree. On a site of more than one language, the list of the languages
  of WEB-TOP-2 must follow the link. The page must carry the `nav` of the
  default tree, per WEB-CHROME-4.
- **WEB-TOP-5** — The `main` of the top-level `404.html` must hold the body of
  `404.html` of each language, in the order of the declaration. Each body must
  sit in its own `section`, with the marks of WEB-LANGUAGE-11.
- **WEB-TOP-6** — The build must remove each `id` from each body of the
  top-level `404.html`, so the page holds no duplicate id. It must resolve each
  relative link of a body against the `404.html` of the tree of that body. In
  the body of `zh-Hans`, `index.html` then becomes `zh-hans/index.html`, and
  `#x` becomes `zh-hans/404.html#x`.

<a id="web-outline"></a>

## The outline

The outline of a page is the list of its headings, with the level of each. A
heading id is the target of a link from outside the page, so the id must not
change with the language, per D-06. A link inside the page follows its heading
to the new id. mandoc(1) makes a link to a section from the text of the link,
and it can give the heading no id. So the build finds that heading by its text.

- **WEB-OUTLINE-1** — The body of a tree page of another language must hold the
  outline of its namesake in the default tree. The two outlines must hold the
  same count of headings, at the same levels, in the same order. The build must
  reject a page whose outline differs. The message must name the page, the
  language and the position of the first heading that differs.
- **WEB-OUTLINE-2** — Each heading of such a page must take the id of the
  heading at the same position in the default page. It must take no id when that
  heading has none.
- **WEB-OUTLINE-3** — The check must compare each heading id of a tree page of
  another language with the id of WEB-OUTLINE-2.
- **WEB-OUTLINE-4** — Each link of such a page to one of its headings must name
  the id of WEB-OUTLINE-2. The build must find the heading of a link of the
  class `Sx` by the text of the link. It must find the heading of each other
  link by its old id. A link to a heading that takes no id stays as it stands.

<a id="web-status"></a>

## The translation status

A translation follows its source, and a source changes. The record of the site
names the version of the source that each translation follows. The author reads
the status of each language with one verb, and the build stays silent.

- **WEB-STATUS-1** — The record is the file `TRANSLATIONS` at the project root,
  beside `.fuguwebrc`. It must not sit below the source directory, where the
  build publishes each plain file as an asset. It must hold one line for each
  translated file, in the form of a SHA256 manifest:
  `SHA256 (<path>) = <digest>`. The path names the translated file from the
  project root, in UTF-8 bytes. It holds no `.` step, no empty step and no final
  solidus. The digest is the SHA-256 of its default source at the time of the
  translation. A record that is absent or empty holds no line.
- **WEB-STATUS-2** — `fuguweb translated <file>...` must write the line of each
  file into the record, with the digest of the default source of that file. It
  must change each file to the path form of WEB-STATUS-1, so `./web/a.html` and
  `web/a.html` name one file. It must reject a file that translates no source of
  the description, and must exit 1. A file that translates a source has a path
  that the record can hold, per WEB-SITE-6. It must keep each other line, and it
  must sort the lines by path. It must exit 3 when it cannot read the record or
  a source.
- **WEB-STATUS-3** — `fuguweb status` must print one line for each part of a
  language other than the default that does not follow its source. The parts are
  each page source, each manual, the footer, and each value of WEB-LANGUAGE-8. A
  line must name the tag, the state, the kind of the part and its name, with one
  tab between two fields.
- **WEB-STATUS-4** — The states are `fallback`, `unrecorded` and `stale`. A part
  that comes from the default language is `fallback`, and a value of the
  description takes this state alone. A translated file with no line in the
  record is `unrecorded`. A translated file is `stale` when its line names a
  digest other than the one that its default source has now.
- **WEB-STATUS-5** — `fuguweb status` must print nothing and exit 0 when each
  part follows its source. It must exit 1 when it prints a line. It must exit 3
  when it cannot read the record or a source, as for a description that does not
  load.
- **WEB-STATUS-6** — The build and the check must not read the record.
- **WEB-STATUS-7** — Two parts that name one translated file must name one
  default source, because the record holds one digest for each file.
  `fuguweb status` and `fuguweb translated` must refuse a description that does
  not obey this rule, and must exit 3. The message must name the file and the
  two sources.

<a id="web-manuals"></a>

## The manuals group

- **WEB-MANUALS-1** — A `manuals` group must take each plain file of its
  directory whose name ends in `.1`, `.3p`, `.5`, `.7` or `.8`. It must not take
  a name that starts with a dot. It must take no directory, and it must read the
  directory rather than glob it.
- **WEB-MANUALS-2** — The group must order its manuals by section, in the order
  1, 3p, 5, 7, 8, and then by file name. A comparison must read bytes, and must
  not read the locale of the builder.
- **WEB-MANUALS-3** — The section order must follow the number of the manual
  section, and `3p` must hold the place of section 3. A new section must enter
  the order at its number.
- **WEB-MANUALS-4** — The build must render each source with mandoc(1), and must
  name the page `<name>.<section>.html`.
- **WEB-MANUALS-5** — The `namespace` of a group must prefix the name of each
  manual of that group.
- **WEB-MANUALS-6** — The manual index must show one heading for each group. The
  heading must take its text from the `heading` of the group, and its anchor
  from the group name. A group with no manual must add nothing to the index.
- **WEB-MANUALS-7** — The block name of a group is the group name. A block name
  is an identifier, and the prose of each language goes in `heading`. A group
  name must be one word of lowercase letters, digits and hyphens. Two groups
  must not share one, and each default group block must take a `heading`.
- **WEB-MANUALS-8** — An `index` page can take a `body`, which opens the page
  below its heading. The heading of the index page is its title. The index must
  write no opening of its own, per WEB-LANGUAGE-12.
- **WEB-MANUALS-9** — The body of a manual page must open with one `h1`, which
  holds the name and the section, as in `fuguweb(1)`. The build must remove the
  head and the foot that mandoc(1) writes, per D-07. The base mandoc(1) of
  OpenBSD also writes a `main` element around the text. The build must replace
  that element with a `div`, so a page holds one `main`.
- **WEB-MANUALS-10** — Each section heading of a manual page must be an `h2`,
  and each subsection heading an `h3`. A heading must hold its text, and no link
  to itself.
- **WEB-MANUALS-11** — A manual page must hold each character outside ASCII as
  text, and not as a character reference.

<a id="web-markdown"></a>

## The Markdown pages

A `markdown` page takes a Markdown file, and `lowdown` renders it. The file can
hold HTML, as a `body` fragment does. A code host shows that HTML, so a
`README.md` must show the same on the host and on the site.

- **WEB-MARKDOWN-1** — The build must render a `markdown` page with `lowdown`,
  and must keep each HTML block and span as written. It must not remove or
  escape one.

<a id="web-keys"></a>

## The key directory

An organization publishes its public keys under one prefix, so a consumer
install can fetch a key and verify a release with it. A site describes each such
directory in `.fuguwebrc`, and the renderer publishes it. A publisher that keeps
two trust domains keeps two directories in one site, and each directory holds
its own root of trust, per D-02.

Every generic part lives in the Fugu library. That library holds the name
pattern, the publication order, and the text of each generated file. It also
holds the armor decoder, the fingerprint, the Web Key Directory hash, and the
manifest parser. The renderer holds the wiring only.

### The description

- **WEB-KEYS-1** — The description must take any number of `keys` blocks. Each
  block name must name a directory below the source directory, and must be one
  path segment. Two blocks must not name one directory.
- **WEB-KEYS-2** — The `keys` block must take an `org` word, which is the first
  field of every key name. A description without one is an error. Two blocks
  must not name one `org` word. The serial of a purpose counts inside one
  directory. A mint of the second block would write a name that the first block
  publishes.
- **WEB-KEYS-3** — The `keys` block must take an optional `contact` value and an
  optional `expires` value. A description that names one and not the other is an
  error. The `expires` value must be a timestamp of RFC 3339. One block alone
  must take the two, because the site publishes one `security.txt`. A second
  block that names either one is an error.
- **WEB-KEYS-4** — The `keys` block must take an optional `url`, which is the
  published prefix of the directory. The value must be an absolute URL.
- **WEB-KEYS-5** — Each `key` block must name the stem of one key file of one
  key directory. The directory that holds the file gives the directory of the
  block. The extension of that file gives the type: `.pub` names a signify key,
  `.asc` an armored OpenPGP key, and `.pem` an X.509 certificate. The renderer
  must reject a stem that names no file, and one that names more than one.
- **WEB-KEYS-6** — Each `key` block must take a `status` of `current`, `next` or
  `retired`, and optional `since` and `until` values.
- **WEB-KEYS-7** — A `key` block of an OpenPGP key must take an optional `email`
  and an optional `fingerprint`. A block of a certificate must take an optional
  `fingerprint`. The renderer must reject an `email` on a certificate, and it
  must reject both settings on a signify key. The `email` value must be a local
  part and a domain. The `fingerprint` of an OpenPGP key must be 40 hexadecimal
  characters, and the one of a certificate must be 64, per WEB-X509-4.
- **WEB-KEYS-8** — The renderer must reject a setting that neither block
  defines, and a `key` block that a second block declares again.
- **WEB-KEYS-9** — The directory must hold a `SHA256` file and a `SHA256.sig`
  file. A directory without either one is an error.
- **WEB-KEYS-24** — The renderer must reject a symlink in the key directory. The
  build would publish the bytes of the target of the link.
- **WEB-KEYS-25** — The renderer must reject a `key` block that stands with no
  `keys` block.
- **WEB-KEYS-29** — The renderer must reject a `keys` name of `.`, of `..`, and
  of the staging directory of the build. None of the three names a directory
  that the build can publish.
- **WEB-KEYS-30** — The renderer must reject a `keys` name that the inventory
  already holds, and one that a second `keys` block holds. Two such names would
  become one name in the output.
- **WEB-KEYS-34** — The renderer must reject a `keys` name that is the path of
  the tree of a declared language. Such a name would take the place of that
  tree, per WEB-LANGUAGE-5.
- **WEB-KEYS-31** — A signify key file must hold an untrusted comment line and a
  key body of 56 base64 characters. The body must decode to 42 bytes that start
  with `Ed`.
- **WEB-KEYS-32** — The human page must carry no footer fragment. A relative
  link of the fragment would resolve against the directory of that page.
- **WEB-KEYS-10** — A description with no `keys` block must build a site with no
  key directory.

### The build

- **WEB-KEYS-11** — The build must copy each key file, each binding file, and
  the `SHA256` pair, byte for byte.
- **WEB-KEYS-12** — The build must generate `<dir>/KEYS` when the set holds an
  OpenPGP key, with every such key in publication order.
- **WEB-KEYS-13** — The build must generate `<dir>/index.html`. The page must
  name the serial, the purpose, the type, the status, the fingerprint and the
  dates of each key. It must name the subject and the validity dates of a
  certificate, per WEB-X509-5. It must link each key file, and must list the
  bindings of each key, per WEB-TRUST-11.
- **WEB-KEYS-14** — The build must generate `.well-known/openpgpkey/hu/<hash>`
  for each email address that a key names, and must generate
  `.well-known/openpgpkey/policy` beside it. The site must hold one such tree,
  and each key directory must write into it. The file must hold the binary form
  of each OpenPGP key of that address, across every directory, in publication
  order. The order must come from the keys, and never from the directory that
  holds them. The policy file must name the site in the default language, per
  WEB-LANGUAGE-3, and no `org` word. One site serves one such file, and each
  directory writes the same bytes there.
- **WEB-KEYS-28** — An address whose keys are all `retired` must serve no file.
  A reader of that file encrypts a message with the key that it holds. The rule
  must read the address across every key directory of the site.
- **WEB-KEYS-15** — The build must generate `.well-known/security.txt` when a
  `keys` block names a contact. The file must carry an `Encryption` field when
  that block names a `url`. The key set of that block must also hold a `current`
  OpenPGP key. The field must name the first such key of the publication order
  of that block. The field must not name a key of another key directory, because
  a binding never crosses one. The checks must report the block that names the
  contact and a `url`, and holds no `current` OpenPGP key. The checks must not
  report that block when no other key directory holds such a key.
- **WEB-KEYS-16** — The inventory must name every path above, and each binding
  file, so the build and the checks read one list.
- **WEB-KEYS-17** — The build must sign nothing and must verify nothing.
- **WEB-KEYS-26** — The build must read each key file before it copies one. It
  must decode an armored key and a certificate, per WEB-X509-1, and it must hold
  a signify key to its own shape. A build that refuses a key must copy no key at
  all. A build that fails later can leave the keys that it wrote, and the checks
  report the tree.

### The checks

- **WEB-KEYS-18** — Each key file must have a `key` block, and each block must
  have a file. A binding file needs no block, and its target and its signer must
  each be a key of the directory.
- **WEB-KEYS-19** — Each name in the directory must match the key name pattern,
  or the binding name pattern.
- **WEB-KEYS-20** — Each purpose must hold exactly one `current` key.
- **WEB-KEYS-21** — `SHA256` must name every key file and every binding file
  with the digest that the file has, and must name nothing else.
- **WEB-KEYS-22** — The declared fingerprint of an OpenPGP key must equal the
  fingerprint that its body gives. The declared fingerprint of a certificate
  must equal the SHA-256 of its DER form.
- **WEB-KEYS-33** — `SHA256.sig` must hold a signify signature. The file must
  hold two lines. The first line must be an `untrusted comment: ` line. The
  second line must hold 100 base64 characters. Those characters must decode to
  74 bytes whose first two bytes spell `Ed`. The build verifies no signature: a
  site that verified its own manifest would prove nothing. It reads the shape
  because a file of another shape fails at every consumer install.
- **WEB-KEYS-23** — The checks must read the source directory, so the answer
  does not depend on a build having run.
- **WEB-KEYS-27** — The human page must take the checks of a page. It must take
  no reachability check, because a site links the key directory when it chooses
  to.

<a id="web-rotate"></a>

## The key rotation

`fuguweb build` and `fuguweb check` read the key directory, and the key verbs
write it. The reader and the writer share one implementation of the name
pattern, the status vocabulary and the manifest.

A consumer verifies a release against the copy of the public key that it holds.
A release that a new key signs therefore fails in each consumer that holds the
old copy. One rotation runs in two steps, and the trust order carries the gap. A
`mint` makes the next key, and a `promote` makes it current.

The verbs sign, and the build signs nothing (WEB-KEYS-17). A verb signs with the
signer of the key type in the Fugu library, and it runs no command of its own. A
signify key signs through `Fugu::Signify`, and a key of another type signs
through `gpg(1)` or `openssl(1)`. The check verifies a signify binding with no
command, and it runs the command of another type, per WEB-TRUST-9.

- **WEB-ROTATE-1** — The verbs must be `fuguweb mint-key`, `fuguweb import-key`
  and `fuguweb promote-key`. Each verb must take a `--purpose` word. `mint-key`
  must take a `--type`, and the default must be `signify`.
- **WEB-ROTATE-2** — A mint must take the next serial of the purpose. It must
  generate a key of the type that `--type` names: a signify pair, or an OpenPGP
  key per WEB-OPENPGP-1. The signify pair and the OpenPGP secret half must take
  no passphrase. It must write the public half into the key directory. It must
  write the private half to the named path, and that file must take no group
  mode and no other mode.
- **WEB-ROTATE-3** — A mint must give the new key the status `current` when the
  purpose holds no current key, and the status `next` otherwise.
- **WEB-ROTATE-4** — The command must read the status of each key from the
  description, and it must assume no status. A key file with no `key` block, and
  a `key` block with no file, must each fail the command.
- **WEB-ROTATE-5** — A mint must refuse a purpose that holds a `next` key
  already, and it must refuse before it generates a pair. A caller stores the
  private half of each mint in one place, so a second `next` key loses the
  private half of the first.
- **WEB-ROTATE-6** — The current root key must sign the manifest. A first root
  mint must sign its own manifest, and a root promote must sign with the new
  root. Every other step must take the private half of the current root as
  `--signer`, per WEB-TRUST-2.
- **WEB-ROTATE-7** — The command must verify the new signature against the
  published public key of the signer. A signature that the key does not verify
  must fail the command.
- **WEB-ROTATE-8** — The command must hold the old signature until a verified
  signature stands in its place. It must leave no directory that holds a
  manifest and no signature.
- **WEB-ROTATE-9** — A promote must make the `next` key of the purpose current.
  It must retire the key that was current with an `until` date. It must write
  the chain binding of WEB-TRUST-4, and must remove each binding that
  WEB-TRUST-5 and WEB-TRUST-7 name.
- **WEB-ROTATE-10** — The command must write the description once in each run. A
  second write leaves the file half changed when it fails.
- **WEB-ROTATE-11** — The command must read the description back after it
  writes, and it must confirm the status of each key that it changed.
- **WEB-ROTATE-12** — The resulting key set must satisfy the status rules of
  `Fugu::KeyDir`, and the command must check the set before it returns.
- **WEB-ROTATE-13** — The command must print one `name=value` line for each fact
  that a caller needs. The facts are the file name, the stem, the serial and the
  status. A promote must add the retired name. A step that writes a key file
  must add the digest and the URL of that file.
- **WEB-ROTATE-14** — The command must reach no network and must hold no token.
  The caller holds the credential.
- **WEB-ROTATE-16** — A mint must record the date of the run as `since` on the
  new `key` block, whatever the type of the key. A promote must record it as
  `until` on the block of the key that it retires. Both dates must read in UTC.
- **WEB-ROTATE-17** — An absent `signify(1)` must fail the command with the exit
  code of a missing tool. A caller then tells it from a rotation that failed.
- **WEB-ROTATE-18** — A mint must refuse a `--secret` path that stands already,
  and one that names the signer. The private half of a key is the one thing that
  a rotation cannot make again. A caller holds each one in one place.
- **WEB-ROTATE-19** — A key directory must hold one root purpose and any number
  of other purposes. One manifest covers the directory, and the current root key
  signs it. A step of another purpose must fail when the directory holds no
  current root.
- **WEB-ROTATE-20** — A step must refuse a key set that breaks the status rules
  of `Fugu::KeyDir`, before it writes. A step over such a set could ask a
  retired key to sign. A directory with no key is the state of a site before its
  first mint, and it must stand. A directory whose keys hold no root must stand
  for the first root mint alone, per WEB-TRUST-1.
- **WEB-ROTATE-21** — The key directory word must name one directory below the
  source directory, as WEB-KEYS-29 holds it. The word is `--dir`, and it selects
  the directory that the step writes. A description with one `keys` block must
  need no such word, and a description with several must refuse a step without
  it.
- **WEB-ROTATE-15** — A directory that no `keys` block names must take one, with
  the organization word and the published prefix that the caller names. The
  block and the first key must arrive in one change, because a block that names
  an empty directory fails every build. A second key directory of a site must
  arrive the same way.
- **WEB-ROTATE-22** — A step that makes a key directory must state that intent.
  The word is `--bootstrap`, and `mint-key` and `import-key` alone must take it.
  A step without it must refuse a `--dir` that no `keys` block names, and must
  refuse before it writes one byte. Each directory holds a root of trust of its
  own, so a mistyped `--dir` would otherwise publish a second root in silence.

<a id="web-trust"></a>

## The root of trust

One signify key of a key directory is the root of trust. Its purpose word is
`root`. The current root key signs the manifest, and every other key of the
directory is a subordinate key. A signify key is vendor neutral, and one line
holds it, so a consumer pins it with one line of its own.

A binding is a detached signature by one key over the public key file of another
key. A subordinate key binds to the current root, and that signature proves that
the holder of the root also holds the subordinate key. A retiring key binds to
the key that takes its place, so a consumer that trusts the old key reaches the
new one. The file name of a binding is `<target file>.<signer stem>.<ext>`. The
extension is `sig` for a signify signer, `asc` for an OpenPGP signer, and `p7s`
for an X.509 signer.

The generic parts live in the Fugu library. Those are the binding name pattern,
the retention rule, and one signer and one verifier for each key type. The
renderer and the verbs hold the wiring only.

- **WEB-TRUST-1** — Each key directory must hold exactly one `current` key of
  the purpose `root`, and that key must be a signify key. A mint and an import
  of the root purpose must refuse a key of another type. The mint must refuse
  before it generates one. A directory with no key is the one exception. The
  first mint of the root purpose must accept a directory whose keys hold no
  root, and must bind each of them per WEB-TRUST-7.
- **WEB-TRUST-2** — The current root key must sign `SHA256`, and no other key
  must sign it. A step of a subordinate purpose must take the private half of
  the current root as `--signer`.
- **WEB-TRUST-3** — Each `current` and `next` key of a subordinate purpose must
  hold one binding over the public key file of the current root.
- **WEB-TRUST-4** — A promote must write a chain binding: the retiring key signs
  the public key file of the key that becomes current. The promote must take the
  private half of the retiring key as `--retiring`.
- **WEB-TRUST-5** — A chain binding must stay published, as a retired key does.
  A step that retires a subordinate key must remove the binding of WEB-TRUST-3
  that the key holds.
- **WEB-TRUST-6** — The manifest must name every key file and every binding
  file, and nothing else.
- **WEB-TRUST-7** — A first root mint and a root promote must write the binding
  of each subordinate key again, in the one step. The step must take the private
  half of each `current` and `next` subordinate key as `--bind <stem>=<path>`.
  It must refuse before it writes when one is absent. A root promote must remove
  each binding whose target is the retired root, except a chain binding of
  WEB-TRUST-4.
- **WEB-TRUST-8** — A step must sign each binding with the signer of the type of
  its signer key. It must verify each binding that it writes against the public
  key of the signer, before one byte reaches the directory. A signature that the
  key does not verify must fail the step.
- **WEB-TRUST-9** — `fuguweb check` must verify each binding against the public
  key of its signer. It must use the verifier of that type in the Fugu library.
  A signify binding needs no command. An absent gpg(1) or openssl(1), for a type
  that the directory holds, is a problem. The check must verify no `SHA256.sig`,
  per WEB-KEYS-33.
- **WEB-TRUST-10** — The check must hold each binding to the retention rule. A
  binding whose signer is `current` or `next` must target the current root. A
  binding whose signer is `retired` must target a key of the same purpose with a
  higher serial. Every other binding is a problem.
- **WEB-TRUST-11** — The human page must list each binding under the key that it
  targets, with the signer and a link to the file.

<a id="web-openpgp"></a>

## The OpenPGP rotation

The renderer publishes an OpenPGP key, and the verbs mint one. gpg(1) makes the
key and the binding, in a temporary home that dies with the run. The Fugu
library holds each call, and the verbs hold the wiring.

- **WEB-OPENPGP-1** — `fuguweb mint-key --type openpgp` must take an `--email`
  address. It must generate one Ed25519 primary key with one Curve25519
  encryption subkey, and that address as its user id. It must write the armored
  public half into the directory as `.asc`, and the armored secret half to
  `--secret`. The `Encryption` field of WEB-KEYS-15 names the key, and a reader
  encrypts to the subkey.
- **WEB-OPENPGP-2** — The mint must write the `email` and the `fingerprint` of
  the new key into its `key` block. It must read the fingerprint from the key
  that it generated, and never from an argument.
- **WEB-OPENPGP-3** — The mint must take an optional `--expires` date of the
  form `YYYY-MM-DD`. It must set the key expiry to the start of that date in
  UTC. It must refuse a date that is not after the day of the run. The reason
  must name the date that the caller gave. A mint without one must set no
  expiry. The key directory retires a key with an `until` date, and the machine
  rotates.
- **WEB-OPENPGP-4** — The check must report a `current` or `next` OpenPGP key
  whose expiry has passed. It must report a `current` key that expires within 30
  days, when its purpose holds no `next` key. A step of the rotation must not
  fail for either report. An expired `current` key stays `current`, so a step
  that failed for that report could never mint the successor. The 30-day report
  reads the whole directory, so it would fail a step of another purpose, and
  that step cannot answer it. A promote of an expired OpenPGP key fails in the
  signer. WEB-TRUST-4 makes the retiring key sign the chain binding, and gpg(1)
  signs nothing with an expired key.
- **WEB-OPENPGP-5** — A binding by an OpenPGP key must be an armored detached
  signature. The verifier must import the one public key of the signer into an
  empty home, and a signature of another key must fail.
- **WEB-OPENPGP-6** — An absent gpg(1) must fail a step with the exit code of a
  missing tool, as WEB-ROTATE-17 holds for signify(1).

<a id="web-x509"></a>

## The certificate

An X.509 certificate is the third key type. A code signing certificate of Apple
Developer ID is one such key, and the renderer knows no issuer by name. An
issuer makes the certificate, so no verb mints one: a verb imports it. The
private key stays with the publisher, and it makes the binding.

- **WEB-X509-1** — The extension `.pem` must select the type `x509`. The file
  must hold one PEM certificate. The check must decode it, and must reject a
  file that holds a private key or a second block.
- **WEB-X509-2** — `fuguweb import-key` must take `--type`, `--purpose`,
  `--file` and `--secret`. It must copy the certificate into the directory under
  the next key name of the purpose, with the status of WEB-ROTATE-3. It must
  write the binding with the private key. An import of another type must take
  the same options, so a key that another tool made can enter the directory.
- **WEB-X509-3** — The `--secret` of an X.509 key must be an unencrypted PEM
  private key. The verbs take no passphrase. A caller that holds a PKCS#12 file
  converts it first.
- **WEB-X509-4** — A `key` block of an X.509 key must take an optional
  `fingerprint` of 64 hexadecimal characters: the SHA-256 of the DER form. The
  import must write it, and the check must compare it, as WEB-KEYS-22 holds for
  an OpenPGP key.
- **WEB-X509-5** — The human page must name the subject and the validity dates
  of a certificate beside the fingerprint. A reader of the page compares the
  subject with what a signed binary reports.
- **WEB-X509-6** — The check must report a `current` or `next` certificate whose
  `notAfter` has passed, and one whose `notBefore` has not come. It must report
  a `current` certificate that expires within 30 days, when its purpose holds no
  `next` key.
- **WEB-X509-7** — A binding by an X.509 key must be a detached CMS signature in
  PEM form. The verifier must pin the one certificate of the signer, and must
  check no chain. The root manifest vouches for the certificate.
- **WEB-X509-8** — The `KEYS` file and the Web Key Directory must skip a
  certificate. Each one serves an OpenPGP reader.
- **WEB-X509-9** — An absent openssl(1) must fail a step with the exit code of a
  missing tool.

<a id="web-actions"></a>

## The workflows

A publisher stores each private key in an organization secret, and no human
handles it. This repository provides the GitHub Actions parts of that: one
reusable workflow, and the composite actions that it composes. A caller
repository holds the credential, the trigger, and its own follow-up. The verbs
hold every trust rule, and the workflow holds the order of the steps.

The pattern of the secret names is `<PREFIX>_<PURPOSE>_KEY_A`,
`<PREFIX>_<PURPOSE>_KEY_B`, and the variable `<PREFIX>_<PURPOSE>_SLOT`. The two
secret names are fixed for one purpose, and the variable moves. The prefix is an
input, so an organization keeps the names that it has.

- **WEB-ACTIONS-1** — The reusable workflow `.github/workflows/keys-rotate.yml`
  must run one step of one purpose in the tree of the caller. Its inputs must
  name the step, the type, the purpose, and the directory. They must name the
  organization word, the published prefix, the environment, and the secret
  prefix. They must name the owner, the visibility list, the publish workflow of
  the caller, and the subordinate purposes of a root step. They must take the
  `--email` and `--expires` of an OpenPGP mint, and the `--file` of an import.
  Each of the three is optional. They must take the `--bootstrap` of a step that
  makes the key directory, per WEB-ROTATE-22, and that input is optional too.
  Every step must name the directory, a promote included, because a site can
  hold several.
- **WEB-ACTIONS-2** — The workflow must output each fact of WEB-ROTATE-13, and
  the digest and the URL of a new key file. A caller declares the key with them.
- **WEB-ACTIONS-3** — Two composite actions must hold the slots.
  `actions/keys-slot` reads the slot variable of each purpose that the caller
  names, and writes the working key files. `actions/keys-store` writes a secret
  from a file and moves the variable. A caller can compose the two on its own.
  One place must read a slot variable, and the workflow must read none itself.
  The `active` and `idle` outputs of `actions/keys-slot` must answer the first
  purpose of the list.
- **WEB-ACTIONS-4** — Each secret must reach a step through the environment, and
  never through the script text. The workflow must read a secret by a name that
  an input forms, through the JSON form of the `secrets` context.
- **WEB-ACTIONS-5** — The workflow must install `fuguweb` with `make deps` of
  the caller, from the release tarballs that the deps manifest of the caller
  pins. It must install nothing of its own. Each install must run before the
  step that mints a token. The workflow must name the install root. It must give
  the module path and the command path of that root to each step that follows.
- **WEB-ACTIONS-6** — The workflow must read the root slot, the purpose slot,
  and the retiring key. A root step that binds each subordinate key again must
  also read the slot of each subordinate purpose. Every other step must read
  none of them. It must give each slot to the verb as a file. A slot that holds
  nothing must leave an empty file.
- **WEB-ACTIONS-7** — The workflow must mask each new private key, and must
  write it into the idle slot before it commits. It must move the variable last,
  after the published site serves each file that the run wrote, byte for byte.
- **WEB-ACTIONS-8** — The workflow must start the publish workflow of the caller
  itself, and must watch no run of it. A push that `GITHUB_TOKEN` makes raises
  no workflow run.
- **WEB-ACTIONS-9** — The workflow must hold no organization name, no domain,
  and no repository list. Each one is an input.
- **WEB-ACTIONS-10** — The workflow must open no pull request, and must declare
  no key anywhere. The caller reads the outputs.
- **WEB-ACTIONS-11** — The workflow must pin each action that it uses to a
  commit, because it runs beside a private key.
- **WEB-ACTIONS-12** — The workflow must remove every private key file that it
  wrote, whatever the outcome of the run.
- **WEB-ACTIONS-13** — The test `t/ci/keys-rotate.t` must hold the order of the
  steps, and each guard above, as text.
- **WEB-ACTIONS-14** — `environment` must bind in the callee job, from the
  input. `permissions`, `concurrency`, and `secrets: inherit` must stay in the
  caller.

<a id="web-style"></a>

## The stylesheet

The stylesheet gives each page that links it the look of a home page of 1994,
set with care. The body face is a serif, the code face is a monospace, and the
ground is the gray of NCSA Mosaic. A rule of two lines sits above each
second-level heading, and a code block shows as an X11 terminal. The sheet
changes the rhythm of the page, not its vocabulary.

A body fragment comes from a hand, from `lowdown`, or from `pod2man`. None of
them writes a class, and the sheet asks for none. A manual page is the one
exception: `mandoc` emits its own class names, and the sheet adopts them.

- **WEB-STYLE-1** — The sheet must reach every element of the chrome and of a
  body fragment by element name alone. It must not need a class there, and the
  chrome must carry none. The classes that `mandoc` emits are the one exception.
- **WEB-STYLE-2** — The sheet must name system fonts only, and must load no
  resource. A page loads itself and the sheet, and nothing else. The forward
  page of WEB-TOP-1 loads no sheet.
- **WEB-STYLE-3** — The sheet must give a light scheme and a dark scheme, and
  the system preference must select one. Each color must appear once, in a
  custom property. The light scheme must take the gray page ground of NCSA
  Mosaic.
- **WEB-STYLE-4** — The Latin face must be Times, and the code face must be
  Courier. The measure must not pass 42em. The line height of Latin text must
  sit between 1.5 and 1.6.
- **WEB-STYLE-5** — The `main` and the `footer` must each show the rule of 1994
  above them: a dark 1px line over a light 1px line. Each second-level heading
  must show the same rule above it. A heading must carry no band, and no other
  decoration. A section heading of a manual page must take no rule.
- **WEB-STYLE-6** — A link must take one color while unvisited, and a second
  color once visited. It must stay underlined. The underline must be one pixel,
  below the baseline.
- **WEB-STYLE-7** — A section heading of a manual page must sit flush with the
  banner, in bold. The section body must sit at an indent on a viewport wider
  than 40em. A narrower viewport can drop both the indent and the heading
  offset. An inline code element of the manual body must take no background.
  Bold alone marks what the reader types, and italic marks what the reader
  substitutes.
- **WEB-STYLE-8** — A `pre` block must show as a 1994 terminal: light text on a
  dark ground, in a sunken well.
- **WEB-STYLE-9** — The sheet must show the list of the languages and the nav
  list each on one line. It must draw the separator between two items. The link
  that carries `aria-current` must show as the current item, with no underline.
  The sheet must reach each one by element name and attribute alone.
- **WEB-STYLE-10** — Each script that the sheet supports must take a stack of
  system fonts after the Latin face, so Latin text keeps its face. The sheet
  must support Han text in its simplified and its traditional form. It must
  reach each stack with `:lang()`.
- **WEB-STYLE-11** — Han text must take no synthetic italic. The sheet must mark
  emphasis in Han text with emphasis marks. The line height of Han text must sit
  between 1.7 and 1.9.
- **WEB-STYLE-12** — The sheet must use logical properties for each margin,
  padding, border, float and alignment. A page of `dir="rtl"` then mirrors.

<a id="web-output"></a>

## The output directory

A build owns its output directory. It writes the site there, and it removes what
the site dropped. A second build over one directory therefore gives the same
tree as the first.

The top level of the output holds the pages for the host, the stylesheet and the
assets. Each language tree is one flat directory of pages below it. Each key
directory is another part below it, and the well-known tree is the last. A file
below the top level takes one of a bounded set of shapes, and rule WEB-OUTPUT-10
states each one. A path of another shape belongs to whoever made it, so the
build keeps it and the clean refuses the tree.

- **WEB-OUTPUT-1** — The build must write a plain file. The file must sit at the
  top level or in the tree of a declared language. Otherwise, it must take a
  shape of the key directory. Rule WEB-OUTPUT-10 states each shape, and rule
  WEB-OUTPUT-14 states the one exception.
- **WEB-OUTPUT-2** — The build must remove each file that the inventory does not
  name. Rule WEB-OUTPUT-1 states which file the build can remove.
- **WEB-OUTPUT-3** — The build must remove each empty directory that it owns. It
  owns a directory that the site holds a name below, a directory of the key
  tree, and the tree of a declared language. It must keep the output directory
  itself.
- **WEB-OUTPUT-4** — The build must keep an entry that rule WEB-OUTPUT-1 does
  not let it write, and must report it. A directory that the description does
  not name, and that is no tree of a declared language, holds the files of
  whoever made it. The tree of a language that the description dropped is one
  such directory.
- **WEB-OUTPUT-5** — The clean must remove a plain file of the top level. It
  must remove a file that the inventory names, and one that takes a shape of
  rule WEB-OUTPUT-10. It must remove a directory that holds a name of the site,
  and a directory of the key tree. It must remove the tree of each declared
  language. Rule WEB-OUTPUT-14 states what it takes in the staging directory. It
  must refuse every other entry, and must name it.
- **WEB-OUTPUT-6** — The build and the clean must read one predicate. The build
  must never remove an entry that the clean refuses. The rule holds for a
  directory as it holds for a file.
- **WEB-OUTPUT-7** — The checks must report each entry of the output that the
  inventory does not name. The report must reach any depth, and an empty
  directory as well.
- **WEB-OUTPUT-8** — The build must refuse a symlink on a path that it writes,
  before it writes one file. An open follows a link, so a build would write the
  site outside its own directory.
- **WEB-OUTPUT-9** — The output path must take no trailing solidus. Each walk of
  the output cuts a relative path out of an absolute one.
- **WEB-OUTPUT-10** — A file below the top level must take one of the shapes
  below. Each shape but the first needs a key directory that the description
  declares:

  - a plain file one level below the tree of a declared language, per
    WEB-LANGUAGE-5;
  - a generated name of a key directory: `SHA256`, `SHA256.sig`, `KEYS` or
    `index.html`;
  - a key file of a key directory, whose name matches rule WEB-KEYS-19. A
    signify key, an OpenPGP key and a certificate each take one shape there, per
    rule WEB-KEYS-5;
  - a binding file of a key directory, whose name matches rule WEB-KEYS-19;
  - `.well-known/security.txt`;
  - `.well-known/openpgpkey/policy`;
  - `.well-known/openpgpkey/hu/<hash>`, where the hash holds 32 characters of
    the z-base-32 alphabet.

  A stale page and a stale key file need this shape set. The inventory names
  what the site holds today, so it cannot answer for a page or a key that the
  description dropped. The tree of a dropped language takes no shape, per
  WEB-OUTPUT-4.

- **WEB-OUTPUT-11** — A `page` block name must be one path segment. Each
  language tree is one flat directory of pages. A name with a solidus writes
  into a directory below the tree, and the build would fail at the write.
- **WEB-OUTPUT-12** — A description with no `keys` block must own no key
  directory shape of rule WEB-OUTPUT-10, and no directory of the key tree. A
  site of another maker holds `security.txt` too, and the clean must not delete
  that site. A key directory that the description dropped is the same: the build
  must keep its files, and the check must report them, per WEB-OUTPUT-4.
- **WEB-OUTPUT-13** — The build and the clean must refuse an output directory
  that no build may own. They must refuse these targets: the root of the
  filesystem, the home directory, the project root, and any directory that holds
  the project. They must refuse the source directory, and each directory of it.
  The output directory of the description is the one exception, because the
  default output directory sits inside the default source directory. A
  description that names neither directory takes the two defaults.
- **WEB-OUTPUT-14** — The staging directory is the one part of the output that
  rule WEB-OUTPUT-1 does not reach. The build writes one flat directory of plain
  files there for each language, under the path of its tree. It removes the
  whole staging directory at the end. The build must refuse a staging directory
  of another shape, and must not remove it. The clean must refuse the same one.
- **WEB-OUTPUT-15** — The clean must refuse a target that holds no stylesheet,
  when the description does not load. Every build writes the stylesheet, so a
  target without it is the output of no build. The rule is a second guard, and
  rule WEB-OUTPUT-13 is the first. A directory that holds a stylesheet of its
  own defeats this one alone.
- **WEB-OUTPUT-16** — The stylesheet, each asset, each key directory and the
  well-known tree must sit at the top level, outside every tree.
- **WEB-OUTPUT-17** — A test that refuses a name, a target or a link because it
  meets another name must compare the folds of the two. The fold is the NFD form
  of Unicode, the canonical decomposition, and then the full case fold. A file
  system without case, such as APFS on Darwin, keeps two names of one fold as
  one entry. These are the tests of WEB-KEYS-1, WEB-KEYS-29, WEB-KEYS-30,
  WEB-KEYS-34 and WEB-OUTPUT-8, and the refusals of WEB-OUTPUT-13. The renderer
  must also refuse two `page` blocks whose names have one fold. It must refuse
  two manuals whose pages have one fold, and a manual and a `page` block whose
  pages have one fold. Each other test must compare the names as they stand, so
  a fold can only make a test refuse more. The exception of WEB-OUTPUT-13 is
  such a test. So is each test of the prune and the clean that decides which
  entry the build owns. A fold there would let the build own more. The fold
  reads the Unicode version of its Perl. A file system of an earlier version
  joins fewer pairs, so a test refuses more, which is safe. A file system of a
  later version can fold a character that the Perl does not know, and a test
  then misses that pair.
