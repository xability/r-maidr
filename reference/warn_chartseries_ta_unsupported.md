# Emit a one-time warning when quantmod::chartSeries() is called with a non-NULL `TA` argument (e.g. `TA = "addVo()"`).

maidr does not read chartSeries' technical-analysis sub-panels, such as
the volume panel `addVo()` adds, so it falls back to native
(non-accessible) rendering for these calls and surfaces a one-time
advisory pointing users to the ggplot2 + tidyquant + patchwork
alternative, which maidr's ggplot2 path reads in full.

## Usage

``` r
warn_chartseries_ta_unsupported()
```

## Value

Invisibly NULL.
