# Create Fallback Image for Unsupported Plots

Renders a plot as a standard PNG image when MAIDR cannot process it.
This is used as a fallback for unsupported plot types or layers.

## Usage

``` r
create_fallback_image(
  plot = NULL,
  format = "png",
  width = 7,
  height = 5,
  res = 150
)
```

## Arguments

- plot:

  A ggplot2 object or NULL for Base R plots

- format:

  Image format: "png" (default), "svg", or "jpeg"

- width:

  Image width in inches (default: 7)

- height:

  Image height in inches (default: 5)

- res:

  Resolution in DPI for PNG/JPEG (default: 150)

## Value

Base64-encoded image data URI string
