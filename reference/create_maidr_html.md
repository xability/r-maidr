# Create HTML document with maidr enhancements using the orchestrator

Create HTML document with maidr enhancements using the orchestrator

## Usage

``` r
create_maidr_html(
  plot,
  use_cdn = NULL,
  shiny = FALSE,
  orchestrator = NULL,
  width = NULL,
  height = NULL,
  ...
)
```

## Arguments

- plot:

  A ggplot2 object

- use_cdn:

  Logical. If `TRUE`, use CDN. If `FALSE` or `NULL` (default), use
  bundled files; see
  [`maidr_html_dependencies()`](https://r.maidr.ai/reference/maidr_html_dependencies.md).

- shiny:

  If TRUE, returns just the SVG content instead of full HTML document

- orchestrator:

  Optional pre-created orchestrator to reuse (avoids double creation).
  The chart is drawn at the size it was created with, and `width` and
  `height` are not read.

- width, height:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md).
  Checked by the caller.

- ...:

  Additional arguments passed to
  [`create_fallback_html()`](https://r.maidr.ai/reference/create_fallback_html.md)

## Value

An htmltools HTML document object or SVG content
