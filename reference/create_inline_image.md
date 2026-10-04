# Create inline image HTML for non-iframe rendering

Creates a simple img tag for a chart MAIDR cannot read, when the chunk's
code asks `knit_print()` for it itself (see
[`knit_print.ggplot()`](https://r.maidr.ai/reference/knit_print.ggplot.md));
a chart knitr prints for a chunk stays knitr's own figure instead.

## Usage

``` r
create_inline_image(
  plot = NULL,
  width = "100%",
  height = "auto",
  size = MAIDR_CHART_SIZE
)
```

## Arguments

- plot:

  A ggplot object or NULL for Base R

- width:

  Width for the image container

- height:

  Height for the image container

- size:

  The size to draw the image at, in inches: a named numeric vector,
  `width` and `height`, as
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)
  gives one

## Value

Character string of HTML with img tag
