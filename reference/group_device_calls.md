# Base R Plot Grouping

This module groups plot calls into logical units: - Each HIGH-level call
starts a new plot group - Subsequent LOW-level calls are associated with
the current plot group - LAYOUT calls affect multi-panel configuration

## Usage

``` r
group_device_calls(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  Graphics device ID

## Value

List of plot groups, each containing HIGH and LOW calls
