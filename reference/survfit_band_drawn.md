# Whether `plot()` of a `survfit` object draws the confidence band

As `survival:::plot.survfit()` decides it: by `conf.int` when given, and
otherwise only for a single curve with standard errors.

## Usage

``` r
survfit_band_drawn(fit, args)
```

## Arguments

- fit:

  A `survfit` object

- args:

  The recorded arguments of the
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Value

TRUE or FALSE
