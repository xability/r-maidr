# Address one grob that a chart draws a datum into as a polygon

A pie's wedges and a mosaic's tiles are each their own grob, so each
needs its own selector – unlike a
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md), whose
bars all live inside one rect grob. gridSVG appends `.1` to the grob
name and wraps the shape in a group of that id, and the `.` has to be
escaped for CSS.

## Usage

``` r
polygon_cell_selector(grob_name)
```

## Arguments

- grob_name:

  A grob name, as
  [`find_graphics_plot_grobs()`](https://r.maidr.ai/reference/find_graphics_plot_grobs.md)
  returns it

## Value

A CSS selector for that grob's polygon
