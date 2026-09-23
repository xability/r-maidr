# Escape a document so it can travel in an HTML attribute

The result is pure ASCII: quotes, angle brackets and ampersands become
entities, and every character outside ASCII becomes a numeric character
reference (`&#xD55C;`). The browser decodes those while it parses the
attribute, so the frame's document holds the original characters, and
nothing between here and the page has a byte left to garble.

## Usage

``` r
escape_for_attribute(html)
```

## Arguments

- html:

  Character string holding a complete HTML document

## Value

The same document, escaped for use as an attribute value

## Details

That last part is the point. The escaped document goes on through
knitr's output, an htmlwidget's JSON and pandoc, and under a C locale –
a container, a CI runner, plenty of servers – more than one of those
treats an unmarked string as native-encoded and rewrites each non-ASCII
byte as the text `<e2>`, `<80>`, `<a6>`. Leaving the bytes unmarked,
which is what this did before, kept them intact only as far as this
function: the ellipsis in the inlined maidr.js arrived in the page as
`<e2><80><a6>`, the script no longer parsed, and a chart rendered
offline was a plain picture. ASCII has no encoding to get wrong.

Byte-wise, and deliberately not
[`htmltools::htmlEscape()`](https://rstudio.github.io/htmltools/reference/htmlEscape.html),
which works in characters and so garbles the same way under a C locale.
`useBytes = TRUE` keeps the substitutions off the encoding: every byte
they replace is ASCII and every byte of a multi-byte UTF-8 sequence is
not, so none can land inside one. Ampersands go first, or the ones the
later replacements introduce would be escaped a second time; the
character references come last for the same reason.

A string marked latin1 is converted to UTF-8 first; an unmarked one is
taken to be UTF-8, which is what the SVG serialisation and the bundle
produce, because [`enc2utf8()`](https://rdrr.io/r/base/Encoding.html) on
it would assume the native encoding and garble it under a C locale.
Unmarked bytes that are not valid UTF-8 are left as they are, since
there is no telling what they spell.

Quotes and angle brackets are enough for a double-quoted attribute: an
apostrophe cannot end one, and a newline inside one is legal and
preserved, so both are left alone.
