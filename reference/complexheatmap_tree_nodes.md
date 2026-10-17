# Dendrograms as maidr.js's `tree` trace reads them

The nodes a ComplexHeatmap draws for one dendrogram, in the shape
[`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md)
gives a pheatmap's: root first and depth first, each node's children in
the order they are drawn (the order of the `dendrogram`'s branches,
whose leaves run in the order of the rows or columns drawn), a leaf
named by its row or column, a cluster by the first and last leaf it
spans and the height it merged at – `"d to e (height 2.99)"` – and a
name repeated among siblings numbered, `"a (2)"`.

## Usage

``` r
complexheatmap_tree_nodes(dends, names, parent = NULL)
```

## Arguments

- dends:

  The dendrograms, one per slice, in drawn order

- names:

  What each leaf of all of them is called, in drawn order

- parent:

  The dendrogram drawn over the slices, or NULL

## Value

A list of nodes, `list(x = name)` with `path` (the ancestors' names,
root first) on every node but the root; empty when nothing was merged or
the names do not fit the dendrograms

## Details

A heat map split into slices has a dendrogram per slice. When
'ComplexHeatmap' clusters the slices too (`cluster_row_slices = TRUE`,
the default), it draws a dendrogram over them, its leaves the slices in
drawn order; that is `parent`, and each of its leaves is replaced by the
slice's own dendrogram, as
[`ComplexHeatmap::merge_dendrogram()`](https://rdrr.io/pkg/ComplexHeatmap/man/merge_dendrogram.html)
joins them. A cluster of slices is named by its own height: where the
slices' means merged when `row_split`, `row_km` and the like split the
heat map, or the height in the dendrogram that was cut when `row_split`
cut it. The drawing lifts the parent above the tallest slice, which is a
place to draw it, not a height anything merged at.

A leaf is matched to its row or column by where it is drawn, not by its
value, which indexes the whole matrix for a cut dendrogram and only the
slice for one clustered within a slice.
