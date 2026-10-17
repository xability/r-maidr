# One categorical annotation track from the legend's colours

Exact when each colour the legend draws stands for one level: every
colour of the track must be one of them, and no two levels share one.

## Usage

``` r
pheatmap_track_from_legend(fill, entry)
```

## Arguments

- fill:

  The colours the track was drawn in

- entry:

  The variable's entry of
  [`pheatmap_annotation_legend()`](https://r.maidr.ai/reference/pheatmap_annotation_legend.md)

## Value

`list(values, levels)` as
[`pheatmap_track_from_values()`](https://r.maidr.ai/reference/pheatmap_track_from_values.md),
or NULL
