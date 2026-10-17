# The subplot grid of a ComplexHeatmap chart, one subplot per heat map read

A horizontal list is one row, left to right; a vertical list is one
column, its rows written bottom first. See
[ComplexHeatmapPlotOrchestrator](https://r.maidr.ai/reference/ComplexHeatmapPlotOrchestrator.md)
for why.

## Usage

``` r
complexheatmap_subplot_grid(subplots, direction)
```

## Arguments

- subplots:

  The subplots, in drawn order: left to right, or top to bottom

- direction:

  The drawn list's `direction`, `"horizontal"` or `"vertical"`

## Value

A list of rows of subplots, each given its id
