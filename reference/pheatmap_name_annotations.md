# Give the annotation tracks of a pheatmap names the selectors can rely on

Give the annotation tracks of a pheatmap names the selectors can rely on

## Usage

``` r
pheatmap_name_annotations(gt)
```

## Arguments

- gt:

  The gtable [`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md)
  returned

## Value

The gtable, its `"row_annotation"` and `"col_annotation"` rect grobs
named
[PHEATMAP_ANNOTATION_GROBS](https://r.maidr.ai/reference/PHEATMAP_ANNOTATION_GROBS.md)
