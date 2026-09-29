# The name of the series a time-series chart draws

[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a time
series titles no value axis, so the default a reader would hear for
every value is the name of its own variable, "x". The series is named as
a formula's variable would be instead: by the expression the chart was
made from – `xyplot(ldeaths)` reads "ldeaths is 3035"
([`lattice_is_time_series()`](https://r.maidr.ai/reference/lattice_is_time_series.md)).

## Usage

``` r
lattice_series_name(plot)
```

## Arguments

- plot:

  A trellis object

## Value

A string; `NULL` for a chart that is not of a time series, or whose
series was handed over as a value rather than named.
