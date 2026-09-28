# The technical-analysis indicators a recorded chartSeries() call draws

[`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)
draws the indicators named by its `TA` argument, which defaults to
`"addVo()"`, and splits a single string on `TAsep` (`";"` by default),
so `TA = "addVo();addSMA()"` draws two. An explicit `TA = NULL`,
`FALSE`, `NA` or `""` draws none.

## Usage

``` r
chartseries_ta_calls(args)
```

## Arguments

- args:

  The recorded arguments of the chartSeries() call

## Value

A character vector of indicator calls, such as `"addVo()"`;
`character(0)` when none is drawn, or `NA` when `TA` is not a character
vector (an evaluated indicator object), which cannot be read.
