# Draw a ComplexHeatmap object once, and grab the drawing

[`ComplexHeatmap::draw()`](https://rdrr.io/pkg/ComplexHeatmap/man/draw-dispatch.html)
draws on an off-screen device the size of the canvas, and the drawing is
grabbed with
[`grid::grid.grabExpr()`](https://rdrr.io/r/grid/grid.grab.html): a
gTree that redraws it, its viewports included, which
[`create_enhanced_svg()`](https://r.maidr.ai/reference/create_enhanced_svg.md)
draws again for the SVG. The cells of the heat map body are then given
names the selectors can rely on
([`complexheatmap_name_cells()`](https://r.maidr.ai/reference/complexheatmap_name_cells.md)).

## Usage

``` r
complexheatmap_capture(plot, canvas)
```

## Arguments

- plot:

  A `Heatmap`, or a `HeatmapList` holding one

- canvas:

  The canvas size, from
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

## Value

A list: `grob`, the gTree; `drawn`, the `HeatmapList` the draw returned;
`heatmap`, the one `Heatmap` in it, with its row and column order as
drawn; `cells`, the names given to the body's cells, by slice, or NULL
when they cannot be selected
