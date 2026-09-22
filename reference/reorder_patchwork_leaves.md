# Put every leaf's data in the order its processors will read the drawing in

The single-plot and facet paths both reorder the plot data before
drawing (`Ggplot2PlotOrchestrator$process_layers()`), because a
segmented bar's DOM order is whatever order its rows arrive in and the
processor declares one order – category by category, fills descending –
to the frontend. A patchwork leaf was drawn from its rows as given, so
its declared order matched the drawing only when the rows happened to be
sorted that way, and a dodged leaf in a composition outlined another
cell's bar for the value announced (#316). Walks the composition the way
[`augment_patchwork_leaves()`](https://r.maidr.ai/reference/augment_patchwork_leaves.md)
does.

## Usage

``` r
reorder_patchwork_leaves(node)
```

## Arguments

- node:

  A patchwork, a ggplot, or anything else (returned as is)

## Value

The node with each leaf's data reordered
