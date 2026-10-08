# The directed graph a ggraph plot was drawn from, or NULL

`ggraph()` keeps the graph it laid out as the `graph` attribute of the
plot's data, a `tbl_graph` that is an `igraph` object.

## Usage

``` r
ggraph_directed_graph(plot_object)
```

## Arguments

- plot_object:

  A ggplot2 plot

## Value

The igraph object when the plot is a ggraph of a directed graph
