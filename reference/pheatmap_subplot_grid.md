# A pheatmap's subplot grid: each layer where it is drawn, rows bottom first

See
[PheatmapPlotOrchestrator](https://r.maidr.ai/reference/PheatmapPlotOrchestrator.md)
for why the rows run bottom first.

## Usage

``` r
pheatmap_subplot_grid(heat, row_tree = NULL, col_tree = NULL)
```

## Arguments

- heat:

  The heat layer

- row_tree, col_tree:

  The tree layers, or NULL for a side with none

## Value

A list of rows of subplots
