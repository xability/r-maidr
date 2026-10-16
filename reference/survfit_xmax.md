# Where `plot()` of a `survfit` object cuts its curves

The right end of `xlim` when given, which overrides `xmax`; else `xmax`.

## Usage

``` r
survfit_xmax(args)
```

## Arguments

- args:

  The recorded arguments of the
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Value

A number, or NULL when the curves run to their end
