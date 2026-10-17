# Draw a ComplexHeatmap object once, and grab the drawing

[`ComplexHeatmap::draw()`](https://rdrr.io/pkg/ComplexHeatmap/man/draw-dispatch.html)
draws on an off-screen device the size of the canvas, and the drawing is
grabbed with
[`grid::grid.grabExpr()`](https://rdrr.io/r/grid/grid.grab.html): a
gTree that redraws it, its viewports included, which
[`create_enhanced_svg()`](https://r.maidr.ai/reference/create_enhanced_svg.md)
draws again for the SVG. The cells of each heat map's body are then
given names the selectors can rely on
([`complexheatmap_name_cells()`](https://r.maidr.ai/reference/complexheatmap_name_cells.md)).

## Usage

``` r
complexheatmap_capture(plot, canvas)
```

## Arguments

- plot:

  A `Heatmap` or `HeatmapList`

- canvas:

  The canvas size, from
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

## Value

A list: `grob`, the gTree; `drawn`, the `HeatmapList` the draw returned;
`heatmaps`, one entry per `Heatmap` in it, in drawn order, each a list
of `heatmap`, with its row and column order as drawn, and `cells`, the
names given to its body's cells, by slice, or NULL when they cannot be
selected; and `heatmap` and `cells`, those of the first
