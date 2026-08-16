# Forget every rebuilt frame

Called when a plot starts being processed, so an entry can only ever be
answered to the run that computed it. See
`Ggplot2PlotOrchestrator$initialize` for why a layer alone cannot
identify a plot.

## Usage

``` r
reset_jitter_cache()
```

## Value

Invisibly `NULL`.
