# Base R State Tracking

This module tracks the plotting state for each graphics device,
including active plot index, panel configuration, and plot grouping.

## Usage

``` r
get_device_state(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  Graphics device ID

## Value

Device state list
