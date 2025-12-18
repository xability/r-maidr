# Create Fallback HTML Content

Creates HTML content with the fallback image, styled to fit in iframes.

## Usage

``` r
create_fallback_html(
  plot = NULL,
  shiny = FALSE,
  format = "png",
  width = 7,
  height = 5
)
```

## Arguments

- plot:

  A ggplot2 object or NULL for Base R plots

- shiny:

  If TRUE, returns just the image tag for Shiny/knitr use

- format:

  Image format (default: "png")

- width:

  Image width in inches

- height:

  Image height in inches

## Value

HTML content string or htmltools object
