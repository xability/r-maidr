# A dendrogram as maidr.js's `tree` trace reads it

Every node of an `hclust`, root first and depth first, the two halves of
each merge in the order they are drawn (`tree$order`). A leaf is named
by the row or column it is in the heat layer; a cluster by the first and
last leaf it spans in that order and the height it merged at –
`"d to e (height 2.99)"` – so a reader knows where in the matrix it
lies. A cluster's leaves are contiguous in the drawn order, so two
sibling clusters never share a name; two leaves with one label do, and
the second is numbered, `"a (2)"`, as the trace needs a node's name
unique among its siblings.

## Usage

``` r
pheatmap_tree_nodes(tree, names)
```

## Arguments

- tree:

  An `hclust`: `merge`, `height`, `order`

- names:

  What each leaf is called, in drawn order

## Value

A list of nodes, `list(x = name)` with `path` (the ancestors' names,
root first) on every node but the root; empty when nothing was merged or
the names do not fit the tree

## Details

No magnitude (`y`) is declared: the trace reads one as a share of the
parent, which a merge height is not, and a leaf has none.
