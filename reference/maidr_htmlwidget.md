# Make a plotly, highcharter or echarts4r htmlwidget accessible

Attaches MAIDR to an interactive chart drawn by another R package, so a
screen reader user can explore it with the keyboard, hear it as
sonification, and read it as text and braille. The chart is read by the
MAIDR JavaScript adapter for the library that draws it, once it has been
drawn in the browser; nothing about it is recomputed in R.

## Usage

``` r
maidr_htmlwidget(widget, use_cdn = FALSE, percentile_bands = NULL)
```

## Arguments

- widget:

  An htmlwidget created by plotly, highcharter or echarts4r.

- use_cdn:

  Logical. Where the MAIDR scripts are loaded from:

  - `FALSE` (default): the copy bundled with this package, which works
    offline and makes no network request.

  - `TRUE`: the jsDelivr CDN, which loads the latest published MAIDR
    unless `maidr.cdn_version` pins one; see
    [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

- percentile_bands:

  echarts4r only. The fan charts the chart draws, each read as one
  percentile band layer; see "Fan charts in echarts4r" below. A list of
  fans, or a single fan, each a list with:

  - `median`: the name of the median's line series.

  - `bands`: a data frame with columns `series`, `lower` and `upper`, or
    a list of lists with those elements, one per band: the name of the
    band's filled series and the quantiles of its lower and upper edges,
    as fractions.

  - `title`, `name` (optional): the layer's title and name, in place of
    the ones read from the chart.

  `NULL` (default) declares none.

## Value

The widget, with MAIDR attached. Print it, return it from a Shiny render
function, or save it as you would the original.

## Details

Supported widgets:

- **plotly**:
  [`plotly::plot_ly()`](https://rdrr.io/pkg/plotly/man/plot_ly.html) and
  [`plotly::ggplotly()`](https://rdrr.io/pkg/plotly/man/ggplotly.html).
  MAIDR's core detects a Plotly chart on the page by itself, so no
  adapter is added.

- **highcharter**:
  [`highcharter::highchart()`](https://jkunst.com/highcharter/reference/highchart.html),
  [`highcharter::hchart()`](https://jkunst.com/highcharter/reference/hchart.html)
  and the stock, map and gantt variants.

- **echarts4r**:
  [`echarts4r::e_charts()`](https://echarts4r.john-coene.com/reference/init.html).
  The chart is switched to ECharts' SVG renderer, since MAIDR highlights
  the mark being read by finding it among the drawn SVG elements, and
  the default canvas renderer draws none.

Which chart types each library supports is decided by its MAIDR adapter;
see <https://maidr.ai/> for the lists. A chart the adapter cannot read
is left as it was drawn, with a warning in the browser console.

The widget keeps working everywhere an htmlwidget does: the RStudio
viewer,
[`htmlwidgets::saveWidget()`](https://rdrr.io/pkg/htmlwidgets/man/saveWidget.html),
R Markdown and Quarto documents, and Shiny
([`plotly::renderPlotly()`](https://rdrr.io/pkg/plotly/man/plotly-shiny.html),
[`highcharter::renderHighchart()`](https://jkunst.com/highcharter/reference/renderHighchart.html),
[`echarts4r::renderEcharts4r()`](https://echarts4r.john-coene.com/reference/echarts4r-shiny.html)),
where the chart is read again each time the server re-renders it.

Applying it twice returns the widget unchanged.

## Fan charts in echarts4r

ECharts has no series for a band: a fan chart is drawn as a median
[`e_line()`](https://echarts4r.john-coene.com/reference/e_line.html)
and, for each band, an invisible line holding its lower edge with an
[`e_area()`](https://echarts4r.john-coene.com/reference/e_area.html) of
its width stacked on it. Nothing in the chart says which quantiles those
edges are, so they are stated with `percentile_bands`, and MAIDR then
reads the median and its bands as one percentile band layer
(experimental): each position announced with its median and the edges of
every band, as ECharts computed them for drawing. Name the median's
series and each band's filled series by the `name` (or `id`) ECharts
knows it by – in echarts4r, the `name` given to
[`e_line()`](https://echarts4r.john-coene.com/reference/e_line.html) and
[`e_area()`](https://echarts4r.john-coene.com/reference/e_area.html), or
the column name when none was given. Each band's `lower` and `upper` are
fractions, `0.05` rather than `5`, every `lower` below 0.5 and every
`upper` above it, and the bands must nest. Draw the fan over a category
x axis, a character or factor column given to
[`e_charts()`](https://echarts4r.john-coene.com/reference/init.html):
over a numeric x axis ECharts stacks each series on the x values rather
than the y, so neither the picture nor the reading is a band. A width
series stacks on a negative lower edge only under
`stackStrategy = "all"`.

The option is read by maidr.js 4.15.0 and later. The copy bundled with
this version of the package is older, so with `use_cdn = FALSE`, or a
`maidr.cdn_version` pinned below 4.15.0, `percentile_bands` is checked
and then ignored with a warning, and the series read as they would be
without it.

## Examples

``` r
if (requireNamespace("plotly", quietly = TRUE)) {
  w <- plotly::plot_ly(
    x = c("Mon", "Tue", "Wed"), y = c(20, 14, 23), type = "bar"
  )
  w <- maidr_htmlwidget(w)
}
if (FALSE) { # \dontrun{
# Pipe-friendly
library(echarts4r)
mtcars |>
  e_charts(wt) |>
  e_scatter(mpg) |>
  maidr_htmlwidget()

# A fan chart: a median and a 90% band drawn as a stacked area
fan <- data.frame(
  week = paste("Week", 1:8),
  median = c(10, 12, 13, 15, 16, 18, 19, 21),
  lower = c(8, 9, 9, 10, 10, 11, 11, 12)
)
fan$width <- 2 * (fan$median - fan$lower)
fan |>
  e_charts(week) |>
  e_line(median, name = "Median") |>
  e_line(lower, stack = "band", name = "lower", symbol = "none",
         lineStyle = list(opacity = 0)) |>
  e_area(width, stack = "band", name = "90% interval", symbol = "none") |>
  maidr_htmlwidget(
    use_cdn = TRUE,
    percentile_bands = list(
      median = "Median",
      bands = data.frame(series = "90% interval", lower = 0.05, upper = 0.95)
    )
  )
} # }
```
