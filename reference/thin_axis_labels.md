# Keep only the tick labels R draws on each axis of an echoed drawing

R's [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws a
tick label only when it clears the last label drawn by a gap: an "m"
wide for labels along the axis, a quarter of an "m" high for labels
across it (`gap.axis`, whose default this is). Labels that would collide
are left out, which is how the y axis of a short panel goes from 10, 12,
14 to 10, 14. gridGraphics echoes every label, so they ran into each
other wherever R thins them: a Base R chart at 4 x 3 in, or the panels
of a 2 x 2 `par(mfrow)` at 10 x 4 in. Each axis's labels are measured as
R measures them, in inches along the axis on a page of the chart's size,
and the ones R leaves out are taken out of the text grob. Labels that
are expressions are all kept, as R draws them all.

## Usage

``` r
thin_axis_labels(drawing, size)
```

## Arguments

- drawing:

  The gTree
  [`base_r_drawing_grob()`](https://r.maidr.ai/reference/base_r_drawing_grob.md)
  echoed

- size:

  The chart's canvas, from
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

## Value

The gTree, its axis-label text grobs holding only the labels R draws
