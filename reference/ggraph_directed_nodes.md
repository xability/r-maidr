# The nodes of a directed ggraph, as the trace declares them

One node per vertex, in vertex order – the order the node layer draws
its points in. The id and label are the vertex's `name` when it has one,
and its index otherwise; `inputs` are the vertices whose edges arrive at
it; its other scalar attributes are announced with it.

## Usage

``` r
ggraph_directed_nodes(plot_object)
```

## Arguments

- plot_object:

  A ggraph plot

## Value

A list of nodes, or NULL when the plot is not a directed ggraph
