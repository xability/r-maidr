# The labels of one axis of a pheatmap, in drawn order

The drawn labels when the axis shows them (`labels_row`, the k-means
clusters' names); else the matrix's dimnames; else, as for an unnamed
matrix, each row's or column's number in the input, in tree order. The
heat layer names its rows and columns by these, and a dendrogram its
leaves.

## Usage

``` r
pheatmap_axis_labels(gt, name, dimnames, tree, count)
```

## Arguments

- gt:

  The gtable

- name:

  `"row_names"` or `"col_names"`

- dimnames:

  The fill matrix's names along the axis

- tree:

  The axis' `hclust`, or NA when it was not clustered

- count:

  The number of rows or columns drawn

## Value

Character vector
