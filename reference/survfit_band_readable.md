# Whether the band `plot()` of a `survfit` object draws, if any, is the object's own: not `conf.int = "only"`, not another level, not of a fit that kept no bounds

Whether the band
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
`survfit` object draws, if any, is the object's own: not
`conf.int = "only"`, not another level, not of a fit that kept no bounds

## Usage

``` r
survfit_band_readable(fit, args)
```

## Arguments

- fit:

  A `survfit` object

- args:

  The recorded arguments of the
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Value

TRUE or FALSE
