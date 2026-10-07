# 008 — The stylesheet

## Status

Proposed. It can land now. Nothing waits on it, and it waits on nothing.

Implements: WEB-STYLE.

## Purpose

The sheet that ships gives the site the look of openbsd.org, and no more. The
measure runs to 110 characters, the type is 16px Times at a tight line height,
and the page has no dark scheme. The look is right, and the reading is hard.

This plan keeps the look and repairs the reading. Times and Courier stay, the
band colors stay, and the link color stays. The measure drops to about 80
characters. The type gains a step in size and in line height. Each band gets a
hairline rule, and each underline thins. A dark scheme answers the system
preference. The chrome drops its one class, so the sheet styles element names
alone.

## Evidence

A mockup of the sheet ran over the built site of this project. It measured each
change against the current sheet, on the front page, on the manual index, and on
fuguweb(1). Two defects of the current sheet surfaced there:

- The section heading of a manual page hangs past the banner. Its negative
  margin is set in its own larger em, so it overshoots the body indent by one
  fifth.
- The section heading inherits the weight of the page heading. A sheet that
  lightens the page heading lightens the manual too.

The one class of the chrome is `banner`, on the `header` element. The selector
`body > header` reaches the same element.

## The change

1. `share/fuguweb/style.css` holds the new sheet. The colors sit in custom
   properties, and one media query swaps them for the dark scheme.
2. `lib/App/FuguWeb/Page.pm` drops the `banner` class, and `t/fuguweb/page.t`
   expects the bare `header`.
3. `t/web/site.t` reads the sheet of the built site, and holds each rule of
   WEB-STYLE that a test can hold. The test refuses a class selector outside the
   `mandoc` set, a `url(` and an `@import`. It expects one
   `prefers-color-scheme` query, and the two font names.
4. `spec/STATUS.md` sets WEB-STYLE to `done`.
5. This plan directory goes in the same change.

## What this plan does not do

It adds no option to the description. The `stylesheet` setting of the
description overrides the sheet whole, as before, and the plan changes no
behavior of the build. It adds no font file and no icon, per WEB-STYLE-2.
