# Group a contour layer's rows into the curves it drew

A contour draws a scalar field as curves of constant value, and
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
has already done the hard half: `level` is a number on every row, and
`piece` separates the curves. A field with two peaks crosses a level
twice and arrives as two pieces, so nothing has to be split apart here –
which is the one place this reading is easier than the matplotlib one,
where both islands come back in a single compound path
(xability/py-maidr#540).

## Usage

``` r
contour_curves(built_data)
```

## Arguments

- built_data:

  A layer's computed data, carrying `x`, `y`, `level` and `piece`, one
  row per vertex

## Value

A list with `data` (one curve per piece, each a list of `x`, `y` and
`level`) and `order` (the piece behind each emitted curve)

## Details

Pieces are emitted in ascending `piece`, which is ascending level and
then draw order within a level, and the returned `order` is that
sequence of piece identifiers – what the selectors are built from, so
the highlight follows the grouping rather than relying on the document
happening to agree.
