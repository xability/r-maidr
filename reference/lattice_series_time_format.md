# The format a time series' time axis is announced with

A time series is drawn against
[`time()`](https://rdrr.io/r/stats/time.html), in years, which the
frontend announces to two decimals unless told otherwise. That keeps
apart the observations of a series sampled fewer than 100 times a year,
but not of a daily one: `EuStockMarkets`, at 260 a year, read "Time is
1991.5" for three trading days running. R prints such a series' times
with the digits that tell them apart (`1991.496`, `1991.500`,
`1991.504`), and so are they announced.

## Usage

``` r
lattice_series_time_format(plot, times)
```

## Arguments

- plot:

  A trellis object

- times:

  The panel's x values

## Value

A `fixed` axis format, or `NULL` when the default keeps the times apart
or the chart is not of a time series.
