# The rows `maidr_survival()` draws from a `survfit` object

The curves [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
of the object draws, as
[`survfit_frame()`](https://r.maidr.ai/reference/survfit_frame.md) reads
them, under the names the axes and legend are titled by: `Time`,
`Survival probability`, `lower`, `upper`, `censored` and, with strata,
`Stratum`, a factor in the object's own order.

## Usage

``` r
survfit_plot_frame(fit)
```

## Arguments

- fit:

  A `survfit` object

## Value

A data frame
