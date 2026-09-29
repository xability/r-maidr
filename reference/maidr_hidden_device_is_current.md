# Whether the current device is MAIDR's hidden device, and not its number

[`is_maidr_temp_device()`](https://r.maidr.ai/reference/is_maidr_temp_device.md)
compares device numbers, and R gives a closed device's number to the
next device opened: after
[`dev.off()`](https://rdrr.io/r/grDevices/dev.html) closes the hidden
device, a `pdf("chart.pdf")`, `svglite()` or
[`ragg::agg_png()`](https://ragg.r-lib.org/reference/agg_png.html)
opened next, or the `pdf(NULL)` that `grid.grabExpr()` opens, has its
number, and a chart printed there would open the viewer and leave the
file or the grob without it. The hidden device is always a
[`pdf()`](https://rdrr.io/r/grDevices/pdf.html) opened on a temporary
file, and R has recorded a pdf device's file in `.Devices` since 3.2.0,
so it is the device whose recorded file is that one. A device that
records no file – svglite's, ragg's, `pdf(NULL)` – is not it.

## Usage

``` r
maidr_hidden_device_is_current()
```

## Value

`TRUE` when the current device is MAIDR's hidden device.
