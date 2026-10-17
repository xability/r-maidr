# The dendrograms a ComplexHeatmap draws on one side, as trees

Nothing when the side is not clustered (`cluster_rows = FALSE`) or its
dendrogram is not shown (`show_row_dend = FALSE`), and nothing for a
slice of a single row, which has no dendrogram to draw. A split side
whose slices are clustered is one tree, the slices' dendrograms joined
under the one drawn over them; one whose slices are not
(`cluster_row_slices = FALSE`) draws a dendrogram per slice, unjoined,
and each is a tree of its own, titled by its slice: the slice's title,
else its number.

## Usage

``` r
complexheatmap_trees(heatmap, side, names)
```

## Arguments

- heatmap:

  The drawn `Heatmap`

- side:

  `"row"` or `"column"`

- names:

  What each row or column is called, in drawn order

## Value

A list of trees, each `list(title, nodes)`; empty when none is drawn
