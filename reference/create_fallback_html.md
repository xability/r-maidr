# Create Fallback HTML Content

Creates HTML content with the fallback image, styled to fit in iframes.

## Usage

``` r
create_fallback_html(
  plot = NULL,
  shiny = FALSE,
  format = get_fallback_format(),
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

  Image format. Defaults to the `maidr.fallback_format` option, which
  [`maidr_set_fallback()`](https://r.maidr.ai/reference/maidr_set_fallback.md)
  sets.

- width:

  Image width in inches

- height:

  Image height in inches

## Value

HTML content string or htmltools object
