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

The documents of the site renderer hold the units of the areas that a plan has
changed. This document holds the description and the languages.
[index.md](index.md) lists the other documents, and its conventions apply.

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
  fuguwebrc(5) and fuguweb-keys(7) do not document. The message must name the
  block and the word.
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
  This rule has a known limit. In a link, the author of a translation can mean
  an id of the default language. That id can also be the old id of another
  heading. The link then follows that other heading, per this rule. An example
  is a link to `#build`, when lowdown(1) gives the id `build` to another heading
  of the translation.

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
