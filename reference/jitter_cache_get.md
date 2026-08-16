# Look up a layer's rebuilt frame

Look up a layer's rebuilt frame

## Usage

``` r
jitter_cache_get(layer, layer_index)
```

## Arguments

- layer:

  The ggplot2 `Layer` the frame was computed from.

- layer_index:

  Index of that layer within its plot.

## Value

The cached data frame, or `NULL` on a miss.
