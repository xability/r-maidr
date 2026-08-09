# Drop `selectors` entries that carry no selector

A layer that resolved no highlight target must say so by OMITTING the
key, never by sending an empty list. The frontend hands
`layer.selectors` straight to `document.querySelectorAll()`, and an
empty array stringifies to `""`, which is a `SyntaxError` – thrown
inside the trace constructor, so the whole figure fails to initialise:
no announcement, no sonification, no braille, no keyboard entry, on a
chart that still looks fine. An absent key is falsy and takes the
frontend's own "no selectors" path instead.

## Usage

``` r
drop_empty_selectors(node)
```

## Arguments

- node:

  A maidr-data node (list, or a leaf)

## Value

The node with empty `selectors` entries removed

## Details

Applied here rather than in each processor because every payload passes
through this one point, and [`list()`](https://rdrr.io/r/base/list.html)
is the honest return value for a processor whose grob lookup found
nothing.
