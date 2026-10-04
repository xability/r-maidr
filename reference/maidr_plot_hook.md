# knitr Plot Hook

Shows the chart a figure holds in place of the figure file knitr saved:
inline in an HTML page, in its own iframe in other HTML output (see
[`knitr_chart_output()`](https://r.maidr.ai/reference/knitr_chart_output.md)).
The chart is the one the figure's page carries the marker of (see
knitr_figure_map.R): a ggplot2 or lattice chart the chunk printed, or
the Base R calls drawn on the page. Any other figure – no chart, two
charts or a chart something else was drawn over, a chart maidr cannot
read – and every figure of an animation or of any other output format
(PDF, Word, ...), is left to the hook maidr's was installed over, which
keeps its caption and alt text. A wrong chart is never shown.

## Usage

``` r
maidr_plot_hook(x, options, original = NULL)
```

## Arguments

- x:

  The plot file path from knitr

- options:

  Chunk options, reduced to the figure's own

- original:

  The plot hook maidr's was installed over; knitr's Markdown hook when
  `NULL`

## Value

The figure's Markdown or HTML
