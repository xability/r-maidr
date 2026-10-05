# Whether a device draws the titles a plot derives

`par("ann")` on the device, without opening one: TRUE, R's default, for
a device that is not the current one, whose
[`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) would be
another's.

## Usage

``` r
device_par_ann(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  Graphics device ID

## Value

TRUE or FALSE
