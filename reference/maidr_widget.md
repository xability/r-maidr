# Create MAIDR htmlwidget

Internal function that creates an interactive MAIDR widget from a ggplot
object. This is called internally by render_maidr() and should not be
called directly. Use maidr_output() and render_maidr() for Shiny
integration instead.

## Usage

``` r
maidr_widget(
  plot,
  use_cdn = NULL,
  width = NULL,
  height = NULL,
  element_id = NULL,
  ...
)
```

## Arguments

- plot:

  A ggplot object, or NULL to auto-detect recorded Base R plots

- use_cdn:

  Logical. Controls where MAIDR.js is loaded from, matching
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md):

  - `TRUE`: Use CDN (requires internet)

  - `FALSE`: Use local bundled files (works offline)

  - `NULL` (default): Auto-detect based on internet availability

  This differs from
  [`maidr_html_dependencies()`](https://r.maidr.ai/reference/maidr_html_dependencies.md),
  where `NULL` means bundled. The widget renders through
  [`create_maidr_iframe()`](https://r.maidr.ai/reference/create_maidr_iframe.md)
  and
  [`create_standalone_html()`](https://r.maidr.ai/reference/create_standalone_html.md),
  which probes for connectivity, so an unset `use_cdn` loads from the
  CDN on a machine that is online.

- width:

  The width of the widget in pixels or CSS units (default: NULL for
  auto-sizing)

- height:

  The height of the widget in pixels or CSS units (default: NULL for
  auto-sizing)

- element_id:

  A unique identifier for the widget (default: NULL for auto-generated)

- ...:

  Additional arguments passed to create_maidr_html()

## Value

An htmlwidget object that can be displayed in RStudio, Shiny, or saved
as HTML

## Details

Uses iframe-based isolation to ensure MAIDR.js initializes properly.
Each widget gets its own isolated JavaScript context where MAIDR.js can
discover and initialize the SVG with maidr-data attribute.
