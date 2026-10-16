# The matrix a pheatmap drew, from its input and the object it returned

The steps
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
takes before colouring, in its order: scaling (`scale_mat()`), the
k-means centres in place of the rows when `kmeans_k` is set (kept in the
result's `kmeans`), then the rows and columns put in the order of their
trees. A value that is not finite – a missing one, or a constant row
scaled to `NaN` – is drawn in `na_col`, and kept as `NA`.

## Usage

``` r
pheatmap_drawn_matrix(mat, scale, result)
```

## Arguments

- mat:

  The matrix the caller passed

- scale:

  The `scale` argument: `"none"`, `"row"` or `"column"`

- result:

  The object
  [`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
  returned

## Value

A numeric matrix, rows top first
