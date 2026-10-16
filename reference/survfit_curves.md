# The curves `plot()` of a `survfit` object draws, as `survival` series

The curves [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
of a `survfit` object draws, as `survival` series

## Usage

``` r
survfit_curves(fit, args)
```

## Arguments

- fit:

  A `survfit` object, already accepted by
  [`survfit_layer_type()`](https://r.maidr.ai/reference/survfit_layer_type.md)

- args:

  The recorded arguments of the
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Value

List of series, one per stratum
