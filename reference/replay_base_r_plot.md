# Replay Base R Plot from Device Storage

Re-executes the recorded Base R plot calls to render the plot.

## Usage

``` r
replay_base_r_plot(device_id, strict = FALSE)
```

## Arguments

- device_id:

  The device ID to get calls from

- strict:

  `TRUE` to stop at a call that cannot be drawn again, as the measure of
  the size the picture needs does (`picture_size()`); `FALSE` draws the
  others, with a warning naming a plot left out
