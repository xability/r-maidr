# Create iframe HTML tag for fallback static image

Creates an iframe element with base64-encoded src containing a static
image. Used when plots contain unsupported layers and fall back to PNG
rendering. Unlike create_maidr_iframe, this does not include MAIDR.js
dependencies.

## Usage

``` r
create_fallback_iframe(
  html_content,
  width = "100%",
  height = "450px",
  plot_id = NULL
)
```

## Arguments

- html_content:

  Character string of HTML content (with img tag)

- width:

  Width of the iframe (default: "100%")

- height:

  Height of the iframe (default: "450px")

- plot_id:

  Unique identifier for the plot

## Value

Character string of iframe HTML
