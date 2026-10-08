# The interval width a `median_hilow` summary layer draws, or NULL

`stat_summary(fun.data = median_hilow)` computes, at each x, the median
and the quantiles `(1 - w) / 2` and `(1 + w) / 2` of the y values there,
`w` being `fun.args$conf.int` (0.95 when unset):
[`Hmisc::smedian.hilow()`](https://rdrr.io/pkg/Hmisc/man/smean.sd.html)
takes them with
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html). The width
is all a percentile band needs to know, and it is read off the layer
rather than inferred from the drawn values.

## Usage

``` r
summary_hilow_width(layer)
```

## Arguments

- layer:

  A ggplot2 layer

## Value

The width, in (0, 1\], or NULL

## Details

Read only where it is unambiguous: `fun.data` is ggplot2's own
`median_hilow` (the function or its name), no `fun`, `fun.min` or
`fun.max` is set beside it, and `fun.args` names nothing but `conf.int`
and `na.rm`. An unnamed argument would reach `conf.int` by position, and
any other summary –
[`mean_cl_normal()`](https://ggplot2.tidyverse.org/reference/hmisc.html),
[`mean_se()`](https://ggplot2.tidyverse.org/reference/mean_se.html) – is
not a quantile interval at all.
