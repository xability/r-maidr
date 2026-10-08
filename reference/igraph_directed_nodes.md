# The nodes of a directed igraph object, as the trace declares them

One node per vertex, in vertex order. The id and label are the vertex's
`name` when it has one, and its index otherwise; `inputs` are the
vertices whose edges arrive at it; its other scalar attributes are
announced with it. Shared by the ggraph reading and Base R's
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of an
igraph.

## Usage

``` r
igraph_directed_nodes(graph)
```

## Arguments

- graph:

  A directed igraph object

## Value

A list of nodes, or NULL when the graph has no vertex or two vertices
share a name
