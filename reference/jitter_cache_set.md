# Remember a layer's rebuilt frame

Remember a layer's rebuilt frame

## Usage

``` r
jitter_cache_set(layer, layer_index, data)
```

## Arguments

- layer:

  The ggplot2 `Layer` the frame was computed from.

- layer_index:

  Index of that layer within its plot.

- data:

  The rebuilt data frame, or `NULL` when the rebuild failed.

## Value

Invisibly `NULL`.
