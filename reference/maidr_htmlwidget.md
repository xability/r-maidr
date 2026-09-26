# Make a plotly, highcharter or echarts4r htmlwidget accessible

Attaches MAIDR to an interactive chart drawn by another R package, so a
screen reader user can explore it with the keyboard, hear it as
sonification, and read it as text and braille. The chart is read by the
MAIDR JavaScript adapter for the library that draws it, once it has been
drawn in the browser; nothing about it is recomputed in R.

## Usage

``` r
maidr_htmlwidget(widget, use_cdn = FALSE)
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
} # }
```
