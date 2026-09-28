# Emit a one-time warning when quantmod::chartSeries() is called with a technical-analysis indicator other than the volume panel (e.g. `TA = "addSMA()"`).

maidr reads the candlesticks and the volume panel `addVo()` draws, but
no other indicator, so it falls back to native (non-accessible)
rendering for these calls and surfaces a one-time advisory pointing
users to the ggplot2 + tidyquant + patchwork alternative, which maidr's
ggplot2 path reads in full.

## Usage

``` r
warn_chartseries_ta_unsupported()
```

## Value

Invisibly NULL.
