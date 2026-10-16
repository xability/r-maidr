# Give the cells of a pheatmap a name the selectors can rely on

Give the cells of a pheatmap a name the selectors can rely on

## Usage

``` r
pheatmap_name_cells(gt)
```

## Arguments

- gt:

  The gtable [`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md)
  returned

## Value

The gtable with its cell rect grob named
[PHEATMAP_CELLS_GROB](https://r.maidr.ai/reference/PHEATMAP_CELLS_GROB.md),
or NULL when it has no matrix of cells
