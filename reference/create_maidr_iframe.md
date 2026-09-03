# Create iframe HTML tag for isolated MAIDR plot

Creates an iframe element whose `srcdoc` carries the complete MAIDR
plot. This isolates each plot in its own document/JavaScript context
while leaving it same-origin with the page, which is what Web Bluetooth
and Web Serial — and so the tactile display — require.

## Usage

``` r
create_maidr_iframe(
  svg_content,
  width = "100%",
  height = "450px",
  plot_id = NULL,
  use_cdn = NULL
)
```

## Arguments

- svg_content:

  Character vector of SVG content with maidr-data attribute

- width:

  Width of the iframe (default: "100%")

- height:

  Height of the iframe (default: "450px")

- plot_id:

  Unique identifier for the plot

- use_cdn:

  Logical. If `TRUE`, use CDN. If `FALSE`, use bundled files. If `NULL`
  (default), auto-detect based on internet availability.

## Value

Character string of iframe HTML
