# Split a vectorised `curve` grob into one curve per row

[`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
draws every row of its layer as a single `curve` grob whose positions
*and* whose `gp` are vectors – measured on ggplot2 3.4.4, a four-row
layer arrives as `GRID.curve.1` with `x1`, `y1`, `x2`, `y2` and
`gp$col`, `gp$fill`, `gp$lwd`, `gp$lty` all of length 4. `gridSVG`'s
`svgStyleAttributes()` rejects that outright – "All SVG style attribute
values must have length 1" – so
[`gridSVG::grid.export()`](https://rdrr.io/pkg/gridSVG/man/grid.export.html)
aborts on the whole plot and no curve chart could be read at all (#195).

## Usage

``` r
split_vectorised_curve_grobs(grob)
```

## Arguments

- grob:

  A grob, gTree, gList, or gtable (or NULL)

## Value

The same tree with every multi-row `curve` grob split row-wise

## Details

A `segments` grob is equally vectorised and exports fine, because
gridSVG has a method that splits it into one element per segment. There
is no such method for `curve`, so the split is done here instead: each
row becomes its own `curve` grob carrying its own slice of the gpar,
gathered under a gTree keeping the original's name. The drawing is
unchanged – every row is drawn with exactly the styling it had – and the
export gains one element per row, which is what a gantt's selectors
address.

Slicing rather than scalarising is the point. Taking `gp[[1]]` would
also satisfy gridSVG and is visibly wrong: measured on a layer coloured
by a third column, the four rows export as `rgb(248,118,109)`,
`rgb(0,186,56)`, `rgb(97,156,255)` and `rgb(0,186,56)`, so collapsing to
the first would paint the whole layer red.

This is an upstream gridSVG gap rather than anything maidr introduced;
drop the split if gridSVG ever gains a `curve` method of its own.
