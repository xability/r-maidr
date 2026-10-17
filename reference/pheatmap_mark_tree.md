# Draw an unseen mark at each node of one of a pheatmap's dendrograms

maidr.js highlights a `tree` node by an element drawn for it, one per
node in the layer's order, and pheatmap draws one link per merge and
nothing at a leaf. So a small circle is drawn at each node
([`pheatmap_tree_marks()`](https://r.maidr.ai/reference/pheatmap_tree_marks.md)),
named
[`pheatmap_node_name()`](https://r.maidr.ai/reference/pheatmap_node_name.md)
in the layer's node order: no fill and no stroke, so the chart looks as
it did, and the highlight paints a copy of it, a dot on the apex of a
link or the tip of a leaf. They are drawn after the links and unclipped,
so a leaf's mark on the edge of the dendrogram's cell is whole.

## Usage

``` r
pheatmap_mark_tree(plot, gt, side)
```

## Arguments

- plot:

  The pheatmap object

- gt:

  Its gtable

- side:

  `"row"` or `"col"`

## Value

The gtable, marked; unchanged when that side has no drawn tree or its
nodes cannot be placed on the drawn links

## Details

The dendrogram's cell then holds a gTree named
`"maidr-pheatmap-<side>-tree"`: the links as drawn, then the marks.
