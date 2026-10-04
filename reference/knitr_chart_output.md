# The output of one chart in a knitted document

Inline where
[`inline_output_ok()`](https://r.maidr.ai/reference/inline_output_ok.md)
allows it, and in its own iframe in any other HTML
([`create_knitr_iframe()`](https://r.maidr.ai/reference/create_knitr_iframe.md)).
A chart that cannot be shown inline – an id the prefixing cannot scope,
or any other error – is shown in an iframe instead, with one warning per
document: a failure never stops the knit.

## Usage

``` r
knitr_chart_output(content, options = list(), figure = FALSE)
```

## Arguments

- content:

  The chart's SVG, from `create_maidr_html(shiny = TRUE)`

- options:

  The chunk options

- figure:

  `TRUE` for a chart the plot hook writes in place of a figure, `FALSE`
  for one `knit_print()` returns

## Value

Character string: Markdown holding a raw HTML block, or the iframe's
HTML
