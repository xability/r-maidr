# Where pheatmap draws each node of a dendrogram

pheatmap draws a dendrogram with its own `draw_dendrogram()`: leaf `i`
of the drawn order at `i - 0.5` of `n` along the tree and at height 0; a
merge midway between its two halves, at its height over the highest
times 1.05, in `npc`; each merge a link up from one half, across at its
height and down to the other. Along the tree, a position `m` is drawn at
`m / n` of the space the gaps (`cutree_rows`, `gaps_row`, ...) leave,
each gap before it adding 4 big points. The column tree is drawn so; the
row tree on its side, `x = 1npc - height` and `y = 1npc - along`.

## Usage

``` r
pheatmap_tree_marks(tree, drawn, horizontal)
```

## Arguments

- tree:

  The `hclust` the dendrogram was drawn from

- drawn:

  The polyline grob pheatmap drew for it

- horizontal:

  `TRUE` for the column tree, `FALSE` for the row tree

## Value

A list of `x` and `y` units, one value per node in the order of
[`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md),
or NULL when a node cannot be placed on the drawn links

## Details

A node is placed at the tip of its leaf or the apex of its link – where
its parent's link meets it. The gaps are read from where the leaves are
drawn
([`pheatmap_tree_gaps()`](https://r.maidr.ai/reference/pheatmap_tree_gaps.md)),
and then every link is checked, point by point, against the polyline
pheatmap drew: a layout this does not foresee places nothing rather than
a mark beside the link it names.
