# Keep the title chartSeries() would have given the call it was made from

Without a `name`,
[`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)
titles the chart with the expression its `x` was written as
(`as.character(match.call()["x"])`), so `chartSeries(AAPL)` is titled
"AAPL". The call is replayed later with the recorded value in place of
that expression, and the title became the series' numbers printed end to
end. The name is taken from the call as written, the way quantmod takes
it, and recorded as an explicit `name`.

## Usage

``` r
record_chartseries_name(args, call_expr)
```

## Arguments

- args:

  The recorded arguments of the chartSeries() call

- call_expr:

  The call as written

## Value

`args`, with `name` added when the caller gave none
