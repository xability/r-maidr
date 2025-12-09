# Create iframe HTML tag for isolated MAIDR plot

Creates an iframe element with base64-encoded src containing the
complete MAIDR plot. Uses data URI with base64 encoding to avoid quote
escaping issues with JSON. This isolates each plot in its own
document/JavaScript context.

## Usage

``` r
create_maidr_iframe(
  svg_content,
  width = "100%",
  height = "450px",
  plot_id = NULL
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

## Value

Character string of iframe HTML
