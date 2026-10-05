# Where on its page a device draws the current plot

`par("fig")` and `par("plt")` on the device, without opening one: the
figure region of the page, and the plot region within that figure.

## Usage

``` r
device_plot_region(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  Graphics device ID

## Value

Numeric vector of eight, the `fig` and then the `plt`; NULL for a device
that is not the current one, whose
[`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) would be
another's
