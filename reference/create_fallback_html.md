# Create Fallback HTML Content

Creates HTML content with the fallback image, styled to fit in iframes.
The image's alt text, which is what a screen reader says of it, names
the chart by its title when it is given one, and says why it is an
image.

## Usage

``` r
create_fallback_html(
  plot = NULL,
  shiny = FALSE,
  format = get_fallback_format(),
  width = 7,
  height = 5,
  title = NULL,
  reason = c("unsupported", "failed")
)
```

## Arguments

- plot:

  A ggplot2 or trellis object, or NULL for Base R plots

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

- title:

  The chart's title, or NULL; the alt text then calls it "Plot"

- reason:

  Why the chart is an image: `"unsupported"`, it holds elements maidr
  cannot read, or `"failed"`, it could not be made interactive
  ([`build_interactive_svg()`](https://r.maidr.ai/reference/build_interactive_svg.md))

## Value

HTML content string or htmltools object
