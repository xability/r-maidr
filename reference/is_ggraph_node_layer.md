# Whether a layer is the node layer a directed ggraph's reading rides on

The first `GeomPoint` layer drawn from the node layout itself – its own
data unset, so it inherits the layout, and with no `filter` aesthetic,
so it draws every node in node order. A later point layer, or a filtered
one, is not claimed.

## Usage

``` r
is_ggraph_node_layer(layer, plot_object)
```

## Arguments

- layer:

  A ggplot2 layer

- plot_object:

  The plot the layer belongs to

## Value

TRUE for the node layer of a directed ggraph
