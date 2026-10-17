# The gaps cut into a pheatmap dendrogram, from where its leaves are drawn

Along the tree, pheatmap draws a position `m` (in leaves, `0` to `n`) at
`m / n * (L - 4G) + 4g` big points in a length of `L`, `G` being the
number of gaps and `g` the number before `m`. The last leaf has every
gap before it, which gives `G`; each leaf then gives its `g`, and a gap
lies wherever `g` steps up.

## Usage

``` r
pheatmap_tree_gaps(leaf_m, drawn, length_along)
```

## Arguments

- leaf_m:

  Each leaf's position along the tree, in leaves

- drawn:

  Where each leaf is drawn along the tree, in big points, in a length of
  `length_along`

- length_along:

  The length the leaves were measured in

## Value

The gaps, as pheatmap takes `gaps_row`: after how many leaves each lies,
in drawn order; NULL when the leaves are not drawn so
