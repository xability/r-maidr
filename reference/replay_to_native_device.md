# Replay Base R plot to native graphics device

For unsupported plots, close the temp device and replay the plot calls
to the native graphics device.

## Usage

``` r
replay_to_native_device(device_id = grDevices::dev.cur())
```

## Arguments

- device_id:

  The device ID to get plot calls from

## Value

NULL (invisible)
