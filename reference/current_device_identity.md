# The current device, told apart from a later one given its number

R gives a closed device's number to the next device opened, so the
number is kept with the device's name and, for a file device, the file
`.Devices` records. Those three are all a
[`pdf()`](https://rdrr.io/r/grDevices/pdf.html) opened on R's default
file once the default device is closed has too, so `marked` is kept as
well: whether the device carries the mark
[`remember_default_device()`](https://r.maidr.ai/reference/remember_default_device.md)
sets on a device R opened by default.

## Usage

``` r
current_device_identity()
```

## Value

A list: `number`, `name`, `path` (`NULL` for no file) and `marked`.
