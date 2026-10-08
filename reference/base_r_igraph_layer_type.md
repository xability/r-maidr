# How Base R's `plot()` of an igraph object is read

A directed graph whose every vertex is drawn as a circle – igraph's
default shape – is a `directed_graph`, the circles being where each node
is outlined. Anything else is `"unknown"`, so the chart is shown as a
picture: read as the points layer
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) otherwise
types it, it was an interactive chart with no points in it.

## Usage

``` r
base_r_igraph_layer_type(graph, args)
```

## Arguments

- graph:

  The igraph object
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) was handed

- args:

  The recorded call's arguments

## Value

`"directed_graph"` or `"unknown"`
