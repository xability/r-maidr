# Group Device Calls into Plot Units

Groups all calls from a device into logical plot units. Each group
contains one HIGH-level call and its associated LOW-level calls.

## Usage

``` r
group_device_calls(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  Graphics device ID

## Value

List of plot groups, each containing HIGH and LOW calls
