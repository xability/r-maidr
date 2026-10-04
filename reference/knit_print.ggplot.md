# Custom knit_print Method for ggplot Objects

Makes a ggplot object a chunk returns an accessible MAIDR chart: inline
in an HTML page, in its own iframe in other HTML output (see
[`knitr_chart_output()`](https://r.maidr.ai/reference/knitr_chart_output.md)).
In any other output format (PDF, Word, ...) the chart is drawn by
ggplot2 and becomes knitr's figure.

## Usage

``` r
# S3 method for class 'ggplot'
knit_print(x, options = list(), ...)
```

## Arguments

- x:

  A ggplot object

- options:

  Chunk options from knitr

- ...:

  Additional arguments (ignored)

## Value

A knit_asis object holding the chart, or `NULL` (invisible) when the
chart is drawn natively

## Details

A chart knitr prints for a chunk is one of the chunk's figures: ggplot2
draws it on the chunk's device, and the plot hook shows the chart in
place of the figure (see `draw_as_knit_figure()`), so knitr numbers,
captions, keeps and holds it with the chunk's other figures, as it would
without maidr. A chart maidr cannot read stays that figure. One the
chunk's code asks `knit_print()` for itself, with no chunk options – as
`cat(knit_print(p))` in a `results = "asis"` loop does – is returned as
the chart's Markdown, and as an inline image when MAIDR cannot read it.

Registered for knitr when maidr loads, so
[`library(maidr)`](https://github.com/xability/r-maidr) is all a
document needs; it installs maidr into the running knit as well.
