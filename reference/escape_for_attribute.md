# Escape a document so it can travel in an HTML attribute

Byte-wise, and deliberately not
[`htmltools::htmlEscape()`](https://rstudio.github.io/htmltools/reference/htmlEscape.html).
That function works in characters, so on a system whose locale is not
UTF-8 it renders every byte it cannot represent as `<ed>`, `<95>`,
`<9c>` — and then escapes the angle brackets it just invented. A Korean
title comes out as `&lt;ed&gt;&lt;95&gt;&lt;9c&gt;`, which is the
garbling the base64 encoding this replaced was chosen to avoid.

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

`useBytes = TRUE` keeps the substitutions off the encoding entirely. It
is safe here because every byte being replaced is ASCII and every byte
of a multi-byte UTF-8 sequence is not, so no replacement can land inside
one.

Ampersands first, or the ampersands introduced by the later replacements
would be escaped a second time.

Quotes and angle brackets are enough for a double-quoted attribute: an
apostrophe cannot end one, and a newline inside one is legal and
preserved, so leaving both alone keeps the document readable and
smaller.

The result is deliberately left unmarked rather than declared UTF-8.
Marking it is what makes the `sprintf` that builds the tag transliterate
it: a UTF-8-marked string handed to `sprintf` under a C locale comes
back with every non-ASCII character rendered `<c3>`, `<a9>`. Unmarked,
the bytes pass through untouched, which is how the base64 encoding this
replaced stayed safe — `charToRaw` never consulted the mark either.
