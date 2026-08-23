# Every grob of one plot drawn by a given element type

[`find_graphics_plot_grob()`](https://r.maidr.ai/reference/find_graphics_plot_grob.md)
answers with the first match, which is what a chart drawing its whole
layer into one grob wants. A chart drawing one grob per datum – a pie's
wedges, a mosaic's tiles – needs all of them, in the order gridGraphics
numbered them.

## Usage

``` r
find_graphics_plot_grobs(grob, element_type, plot_index)
```

## Arguments

- grob:

  The grob tree to search

- element_type:

  The element type, e.g. `"polygon"`

- plot_index:

  The plot (panel) index to match

## Value

Character vector of grob names, ascending by grob number

## Details

Sorted by the trailing grob number rather than by tree order or
lexicographically: `density =` shading interleaves a segments grob
between a pie's wedges so tree order is not contiguous, and a
lexicographic sort would put `-polygon-10` before `-polygon-2`.
