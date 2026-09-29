# Remember the current device as one R opened by default

[`screen_device_is_current()`](https://r.maidr.ai/reference/screen_device_is_current.md)
counts it as the reader's screen. It is kept by
[`current_device_identity()`](https://r.maidr.ai/reference/current_device_identity.md),
with a mark set on the device itself: R gives a closed device's number
to the next device opened, and a
[`pdf()`](https://rdrr.io/r/grDevices/pdf.html) the reader opens, or the
`pdf(NULL)` `grid.grabExpr()` opens, can have the number, name and file
of one since closed, but not the mark. `err` is a graphical parameter R
keeps for each device and documents as unimplemented, so setting it
draws nothing; a device opened later starts at `0`.

## Usage

``` r
remember_default_device()
```

## Value

NULL (invisible)
