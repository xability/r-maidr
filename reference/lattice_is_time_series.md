# Whether a chart is `xyplot()` of a time series

[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a time
series draws it through a formula of its own making, `x ~ tt`, and a
chart is known by what that formula leaves: `xlab.default` `"tt"` and
`ylab.default` `"x"`, from a call whose data is not a formula.

## Usage

``` r
lattice_is_time_series(plot)
```

## Arguments

- plot:

  A trellis object

## Value

`TRUE` or `FALSE`
