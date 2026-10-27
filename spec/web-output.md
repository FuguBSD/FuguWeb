# The output

This document holds the stylesheet and the output directory. [web.md](web.md)
holds the model of the site, and the conventions of [index.md](index.md) apply.

<a id="web-style"></a>

## The stylesheet

The stylesheet gives each page that links it the look of a home page of 1994,
set with care. The body face is a serif, the code face is a monospace, and the
ground is the gray of NCSA Mosaic. A rule of two lines sits above each
second-level heading, and a code block shows as an xterm window of X11. The
sheet changes the rhythm of the page, not its vocabulary. Its one word is the
program name `xterm`, per WEB-LANGUAGE-12.

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
  Courier. A `pre` block takes the face of WEB-STYLE-8. Text looks as large as
  the area that its lowercase letters cover: the x-height times the mean width
  of a letter. Each code face must take the size at which it covers the area of
  Times New Roman. Courier must take 0.846em, and the Menlo of an xterm must
  take 0.767em. A code element in a code element must keep the face and the size
  of its parent. The measure must not pass 42em. The line height of Latin text
  must sit between 1.5 and 1.6. A heading and a `pre` block must each take their
  own line height of 1.2. The line height of the body text does not hold there.
  Text must take no kerning and no common ligatures, as the bitmap fonts of X11.
  It must keep its contextual forms, because some scripts need them.
- **WEB-STYLE-5** — The `main` and the `footer` must each show the rule of 1994
  above them: a dark 1px line over a light 1px line. Each second-level heading
  must show the same rule above it. A heading must carry no band, and no other
  decoration. A section heading of a manual page must take no rule.
- **WEB-STYLE-6** — A link must take one color while unvisited, and a second
  color once visited. It must stay underlined. The underline must be one pixel,
  below the baseline. The underline must go through the descenders, as in X11. A
  linked image must show a frame of 2px in the link color, as in Mosaic. A link
  must show in red while the reader pushes it, as in Netscape 1.x. The keyboard
  focus must show as a dotted ring of one pixel, as in Windows 3.1.
- **WEB-STYLE-7** — A section heading of a manual page must sit flush with the
  banner, in bold. The section body must sit at an indent on a viewport wider
  than 40em. A narrower viewport can drop both the indent and the heading
  offset. An inline code element of the manual body must take no background.
  Bold alone marks what the reader types, and italic marks what the reader
  substitutes. A display that holds a `pre` block must take no indent. The frame
  of the xterm marks the block, and a line of the block then holds more columns.
- **WEB-STYLE-8** — A `pre` block must show as an xterm in the default window
  frame of twm, the window manager of X11R6. The light scheme must show the
  black text on white of the default xterm. The dark scheme must show light text
  on a dark ground. The frame must take the default colors of twm: a slategrey
  border, and a teal title bar with gray85 text. The title bar must show the
  iconify dot, the title `xterm` in Helvetica Bold, the even stipple, and the
  resize button. A screen reader must not read the title. A selection in the
  block must show in reverse video. A long line must wrap at the edge of the
  window, as in xterm. The block then does not scroll, and the title bar stays
  in view. The text must take a sans-serif monospace face, as the default font
  `fixed` of xterm. The text must sit 2px inside the frame, as the default
  internal border of xterm.
- **WEB-STYLE-9** — The sheet must show the list of the languages and the nav
  list each on one line. It must set the list of the languages at the end of the
  line of the banner link. A narrow viewport can put the list below the link. It
  must draw the separator between two items. It must enclose the nav list in a
  pair of brackets. It must write each separator and each bracket as text, with
  one word space between it and each item next to it. The link that carries
  `aria-current` must show as the current item. It must show in the text color,
  with no underline and no bold. The sheet must reach each one by element name
  and attribute alone.
- **WEB-STYLE-10** — Each script that the sheet supports must take a stack of
  system fonts after the Latin face, so Latin text keeps its face. The sheet
  must support Han text in its simplified and its traditional form. It must
  reach each stack with `:lang()`. A tag of `zh` must take the traditional form
  when its script is `Hant`. A tag of `zh` with no script must take it when its
  region is `TW`, `HK` or `MO`. A tag of `zh` must take the simplified form when
  its script is `Hans`. A tag of `zh` with no such region must take it when it
  has no script, or a script other than `Hant` and `Latn`. A tag of `zh` with
  the script `Latn` holds Latin text. It must take the Latin face and the line
  height of Latin text, per WEB-STYLE-4, in each region. Each tag above must
  take its face and its line height whether the engine matches a range by basic
  or by extended filtering. In the region `TW`, `HK` or `MO`, a tag of `zh` with
  a script other than `Hans`, `Hant` and `Latn` can take either form. The two
  filterings give it different forms.
- **WEB-STYLE-11** — Han text must take no synthetic italic. The sheet must mark
  emphasis in Han text with emphasis marks and no italic, on an `em` and on the
  `Em` class of `mandoc`. A bare `i` must take the emphasis marks and keep its
  italic, because it marks what the reader substitutes, per WEB-STYLE-7. Each of
  the three must keep its italic and take no marks in a tag of `zh` with the
  script `Latn`, per WEB-STYLE-10. The line height of Han text must sit between
  1.7 and 1.9. A heading and a `pre` block take their own line height, per
  WEB-STYLE-4.
- **WEB-STYLE-12** — The sheet must use logical properties for each margin,
  padding, border, float and alignment. A page of `dir="rtl"` then mirrors. The
  title bar of a `pre` block must keep the left-to-right order of X11 on each
  page, because twm has no right-to-left mode.

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
  default output directory sits inside the default source directory. The
  exception does not cover a target that rule WEB-OUTPUT-18 refuses. A
  description that names neither directory takes the two defaults.
- **WEB-OUTPUT-14** — The staging directory is the one part of the output that
  rule WEB-OUTPUT-1 does not reach. The build writes one flat directory of plain
  files there for each language, under the path of its tree. It removes the
  whole staging directory at the end. The build must refuse a staging directory
  of another shape, and must not remove it. The clean must refuse the same one.
- **WEB-OUTPUT-15** — The clean must refuse a target that holds no stylesheet,
  when the description does not load. Every build writes the stylesheet, so a
  target without it is the output of no build. The rule is a second guard, and
  rules WEB-OUTPUT-13 and WEB-OUTPUT-18 are the first. A directory that holds a
  stylesheet of its own defeats this one alone.
- **WEB-OUTPUT-16** — The stylesheet, each asset, each key directory and the
  well-known tree must sit at the top level, outside every tree.
- **WEB-OUTPUT-17** — A test that refuses a name, a target or a link because it
  meets another name must compare the folds of the two. The fold is the NFD form
  of Unicode, the canonical decomposition, and then the full case fold. A file
  system without case, such as APFS on Darwin, keeps two names of one fold as
  one entry. These are the tests of WEB-KEYS-1, WEB-KEYS-29, WEB-KEYS-30,
  WEB-KEYS-34 and WEB-OUTPUT-8, and the refusals of WEB-OUTPUT-13 and
  WEB-OUTPUT-18. The renderer must also refuse two `page` blocks whose names
  have one fold. It must refuse two manuals whose pages have one fold, and a
  manual and a `page` block whose pages have one fold. Each other test must
  compare the names as they stand, so a fold can only make a test refuse more.
  The exception of WEB-OUTPUT-13 is such a test. So is each test of the prune
  and the clean that decides which entry the build owns. A fold there would let
  the build own more. The fold reads the Unicode version of its Perl. A file
  system of an earlier version joins fewer pairs, so a test refuses more, which
  is safe. A file system of a later version can fold a character that the Perl
  does not know, and a test then misses that pair.
- **WEB-OUTPUT-18** — The build and the clean must refuse an output directory
  that holds a source. The message must name the target and the source. A target
  holds a path that is the target or lies below it. The prune removes each file
  of the top level that the site does not name. The clean removes the whole
  target, so either one would remove the source. A source is a body, a footer, a
  Markdown page, a manual or a POD sidecar of each language. The stylesheet that
  the description names is a source too. The source directory, each key
  directory and the directory of each `manuals` and `modules` group of each
  language are also sources. The build and the clean must also refuse a target
  inside a key directory or inside the directory of a group. Such a directory
  holds the content of the project, as the source directory does. A description
  that does not load names its source directory and its key directories alone,
  and rule WEB-OUTPUT-15 guards the rest.
