# Put a layer's built points back where its data puts them

Put a layer's built points back where its data puts them

## Usage

``` r
undisplace_layer(plot, layer_data, layer_index)
```

## Arguments

- plot:

  The ggplot2 object.

- layer_data:

  The layer's built data, as read from `built$data`.

- layer_index:

  Index of the layer within the plot.

## Value

`layer_data` with `x` and `y` restored when the layer was jittered and
the rebuild lined up, and unchanged otherwise.
