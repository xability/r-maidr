# The annotation arguments of a pheatmap() call, as passed

The annotation arguments of a pheatmap() call, as passed

## Usage

``` r
pheatmap_kept_annotations(matched)
```

## Arguments

- matched:

  The call's arguments, matched to
  [`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)'s

## Value

`list(row, col, colors)`, each NULL when not given as pheatmap takes it,
or NULL when there are no annotation data frames
