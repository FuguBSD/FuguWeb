# The pages

This document holds the chrome, the links, the top-level pages, the manuals
group and the Markdown pages. [web.md](web.md) holds the model of the site, and
the conventions of [index.md](index.md) apply.

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
