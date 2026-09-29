# Make the screen MAIDR opened last current, or open one

Plain R draws every chart on one screen, each new page replacing the
last, so the default device MAIDR opened last that is still open is used
again, known by its identity
([`remember_default_device()`](https://r.maidr.ai/reference/remember_default_device.md)).
A new one is opened only when none is left.

## Usage

``` r
use_default_device()
```

## Value

NULL (invisible)
