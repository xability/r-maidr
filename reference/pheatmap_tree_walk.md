# [`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md), each node beside the one of the `hclust` it is

[`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md),
each node beside the one of the `hclust` it is

## Usage

``` r
pheatmap_tree_walk(tree, names)
```

## Arguments

- tree, names:

  As
  [`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md)
  takes them

## Value

A list: `nodes`, as
[`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md)
returns them, and `ids`, the `hclust`'s number for each in the same
order – `-i` for the leaf of input row `i`, `k` for the merge in row `k`
of `merge`
