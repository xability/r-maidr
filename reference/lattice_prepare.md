# Rearrange a trellis object's rows so its marks are drawn in reading order

The drawing is unchanged; only the order the marks are drawn in is.

## Usage

``` r
lattice_prepare(plot)
```

## Arguments

- plot:

  A trellis object

## Value

The object, with each packet's rows reordered and what they were drawn
with kept with them.

## Details

- [`panel.barchart()`](https://rdrr.io/pkg/lattice/man/panel.barchart.html)
  and
  [`panel.dotplot()`](https://rdrr.io/pkg/lattice/man/panel.dotplot.html)
  draw a mark per row, in the order of the rows, and the frontend pairs
  a bar-shaped layer's marks with its values in document order. Sorting
  each packet's rows by category – then by group – makes that the order
  the categories run along the axis, which is the order a reader walks
  them in.

- Whatever else those panels hand out by row keeps the row it went to.
  Without groups, a style given as a vector – `col = c("red", "blue")` –
  colours the marks in the order they are drawn, first mark first, so
  sorting the rows alone would repaint the bars; the style is sorted
  with them, into a copy for each packet, since each packet sorts its
  own rows and starts again from the style's first value. With groups a
  style goes by group rather than by row. A dot plot draws a guide line
  per level in the order the rows first name the levels, and is given
  that order.

- A dot plot joined by lines (`type` holding `"l"`, `"b"` or `"o"`)
  keeps its rows: the lines run through them in their order, which is
  the shape of the line. Its dots are then in level order only where the
  rows already were; where they are not,
  [LatticeDotLayerProcessor](https://r.maidr.ai/reference/LatticeDotLayerProcessor.md)
  cannot pair them with their levels, and the chart falls back to an
  image.

- [`panel.bwplot()`](https://rdrr.io/pkg/lattice/man/panel.bwplot.html)
  gives a level whose values are all missing a box of missing
  statistics, which the exporter draws as no polygon; the boxes after it
  are then numbered one short. Naming the levels that hold a value as
  the ones to draw (`levels.fos`) leaves the same boxes drawn, numbered
  as they are counted. The rows themselves are kept: `varwidth = TRUE`
  sizes each box by the rows of the level holding the most, missing
  values included.
