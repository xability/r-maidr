# Restate a rect grob's negative heights and widths as positive ones

[`gridSVG::grid.export()`](https://rdrr.io/pkg/gridSVG/man/grid.export.html)
warns "number of items to replace is not a multiple of replacement
length" on any rect grob drawn with a negative height or width, and the
warning reaches
[`save_html()`](https://r.maidr.ai/reference/save_html.md), where a plot
that warns falls back to a picture.

## Usage

``` r
normalise_negative_rects(grob)
```

## Arguments

- grob:

  A grob, gTree, gList, or gtable (or NULL)

## Value

The same tree with every rect's extent stated positively

## Details

Measured on a bare `rectGrob()` with nothing else to it: four rects with
positive heights export silently, and the same four with two heights
negated warn. So this is an upstream gridSVG defect rather than anything
about a particular chart – but it is reached by an ordinary one.
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
every tile from a baseline with `just = c("left", "bottom")` and a
signed height, so a cell below expectation is a negative height by
construction (#266); every association plot would warn.

A rect at `(y, h)` with `h < 0` covers the same pixels as one at
`(y + h, |h|)`, so the drawing is unchanged – only the arithmetic
gridSVG does with it. The same holds for `x` and a negative width.

Drop this repair if gridSVG ever handles negative dimensions itself.
