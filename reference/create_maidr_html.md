# Create HTML document with maidr enhancements using the orchestrator

Create HTML document with maidr enhancements using the orchestrator

## Usage

``` r
create_maidr_html(
  plot,
  use_cdn = NULL,
  shiny = FALSE,
  orchestrator = NULL,
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

  Optional pre-created orchestrator to reuse (avoids double creation)

- ...:

  Additional arguments passed to internal functions

## Value

An htmltools HTML document object or SVG content
