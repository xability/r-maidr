# The canvas a chart is drawn on

The size asked for, each side that was not asked for taken from
[MAIDR_CHART_SIZE](https://r.maidr.ai/reference/MAIDR_CHART_SIZE.md), or
from
[MAIDR_CANDLESTICK_SIZE](https://r.maidr.ai/reference/MAIDR_CANDLESTICK_SIZE.md)
for a candlestick chart. A candlestick chart smaller than
[MAIDR_CANDLESTICK_SIZE](https://r.maidr.ai/reference/MAIDR_CANDLESTICK_SIZE.md)
on either side is drawn at that size on that side instead. When that
size was asked for, a message (of class `maidr_chart_size_message`)
names the size it is drawn at: a size asked for is never changed
silently. One that was not – a knitted document's figure size, which
every chunk that sets none is drawn at – is enlarged without a word, as
before maidr read a chunk's size. A Base R chart too small for a size no
one asked for is enlarged too, and says so
([`base_r_page_that_fits()`](https://r.maidr.ai/reference/base_r_page_that_fits.md)).

## Usage

``` r
chart_canvas_size(
  width = NULL,
  height = NULL,
  candlestick = FALSE,
  asked = !is.null(width) || !is.null(height)
)
```

## Arguments

- width, height:

  The size in inches, or `NULL` for none. Checked by the caller, with
  [`check_chart_size()`](https://r.maidr.ai/reference/check_chart_size.md).

- candlestick:

  Whether the chart holds a candlestick layer.

- asked:

  Whether `width` and `height` were asked for: by default when either is
  given. A knitted chunk's are asked for only when they are not the
  document's own (`knitr_chart_size()`).

## Value

A named numeric vector, `width` and `height`, in inches.
