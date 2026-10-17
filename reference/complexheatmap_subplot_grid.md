# The subplot grid of a ComplexHeatmap chart: its heat maps and their trees

One subplot per heat map read, in drawn order – a horizontal list left
to right, a vertical list top to bottom – and one for each side's trees,
where they are drawn: a row tree beside its heat map, left or right, a
column tree above or below it, a side's trees (one per slice when the
slices are not clustered) as layers of one subplot. Every other place on
the grid is an empty subplot, and a row or column of the grid with
nothing in it is left out. The rows are written bottom first; see
[ComplexHeatmapPlotOrchestrator](https://r.maidr.ai/reference/ComplexHeatmapPlotOrchestrator.md)
for why.

## Usage

``` r
complexheatmap_subplot_grid(subplots, direction, trees = NULL)
```

## Arguments

- subplots:

  The heat maps' subplots, in drawn order

- direction:

  The drawn list's `direction`, `"horizontal"` or `"vertical"`

- trees:

  For each heat map, what
  [ComplexHeatmapPlotOrchestrator](https://r.maidr.ai/reference/ComplexHeatmapPlotOrchestrator.md)'s
  `read_trees()` gives, or NULL for none

## Value

A list of rows of subplots, each given its id

## Details

A single heat map with both trees is
`[[row tree, heat], [empty, column tree]]`, as a pheatmap's grid is.
