# Replay Base R Plot from Device Storage

Re-executes the recorded Base R plot calls to render the plot.

## Usage

``` r
replay_base_r_plot(device_id, strict = FALSE, asked = TRUE)
```

## Arguments

- device_id:

  The device ID to get calls from

- strict:

  `TRUE` to stop at a call that cannot be drawn again, as the measure of
  the size the picture needs does (`picture_size()`); `FALSE` draws the
  others, with a warning naming a plot left out

- asked:

  Whether the size the picture is drawn at was asked for: at one no one
  asked for, a
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) maidr
  did not record keeps the shares of the page R gave its cells however
  small the page, and the picture is drawn larger where they leave a
  plot no room (`layout_sizes_on_page()`)
