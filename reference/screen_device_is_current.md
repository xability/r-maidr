# Whether a chart printed now would be drawn on a screen

No device open counts, since printing would open the default screen
device, and so does MAIDR's own hidden device, which only Base R
recording opens. Otherwise the current device has to be one R knows as
interactive, or one of the IDE devices R does not list: RStudio's, and
httpgd's, which VS Code uses. Anything else –
[`pdf()`](https://rdrr.io/r/grDevices/pdf.html),
[`png()`](https://rdrr.io/r/grDevices/png.html), `svglite()`, the
off-screen device `grid.grabExpr()` opens – is a destination the caller
chose for the drawing.

## Usage

``` r
screen_device_is_current()
```

## Value

`TRUE` when the current device is a screen.
