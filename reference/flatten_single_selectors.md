# Collapse a layer's selector list into the one string its type is read as

Every processor builds `selectors` with
[`list()`](https://rdrr.io/r/base/list.html) or
[`lapply()`](https://rdrr.io/r/base/lapply.html), so even a single CSS
selector reaches
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
as a list of one, and `auto_unbox = TRUE` cannot unbox a list: the
payload says `"selectors": ["#geom_rect\\.rect\\.2\\.1 rect"]`. maidr.js
4.x reads that array as one selector per data point, resolves it to one
element for seven bars, and declines the whole layer – navigation and
speech keep working while nothing on the chart ever changes colour
(#316). Measured in headless Chromium against the bundled 4.9.0: ggplot2
bar, point, histogram, dodged, stacked and pie, and Base R
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md), all
announced their values and drew no highlight; rewriting only the JSON to
a string restored every one of them.

## Usage

``` r
flatten_single_selectors(node)
```

## Arguments

- node:

  A maidr-data node (list, or a leaf)

## Value

The node with single-selector layers carrying a string

## Details

For a layer whose type is in
[SINGLE_SELECTOR_LAYER_TYPES](https://r.maidr.ai/reference/SINGLE_SELECTOR_LAYER_TYPES.md),
a flat character vector or list of strings becomes one string. Several
entries are joined with `", "`: a selector list, which
`querySelectorAll()` resolves in document order – the same order the
layer's points are in, since a processor that names several containers
(Base R [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
one polygon grob per wedge) walks them in drawing order. Nested lists (a
per-cell grid), named objects (`BoxSelector`) and anything not made of
strings are left exactly as they are, and so is every other layer type.

Applied where
[`drop_empty_selectors()`](https://r.maidr.ai/reference/drop_empty_selectors.md)
is, and for the same reason: every payload passes through this one
point, the processors are honest about what they found, and the shape
the frontend reads is decided once, against the bundle actually shipped,
where a future bundle bump has one place to look.
