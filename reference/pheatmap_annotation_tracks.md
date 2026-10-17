# The annotation tracks of one side of a pheatmap

Each variable of `annotation_row` or `annotation_col` is drawn as a
track of cells along the matrix, one per row or column. The variables
are read in the order pheatmap draws them outward from the matrix – the
data frame's first column next to it – and each is named by its column
name.

## Usage

``` r
pheatmap_annotation_tracks(plot, gt, side)
```

## Arguments

- plot:

  The pheatmap object

- gt:

  The gtable, its tracks named
  [PHEATMAP_ANNOTATION_GROBS](https://r.maidr.ai/reference/PHEATMAP_ANNOTATION_GROBS.md)

- side:

  `"row"` or `"col"`

## Value

A list of tracks, in the data frame's column order (nearest the matrix
first): `list(name, side, values, levels, cells)`, `levels` NULL for a
numeric track, `cells` each cell's selector in drawn order, NULL when
the drawn rects are not one per value in drawn order

## Details

**Values.** pheatmap matches the data frame's rows to the matrix by the
matrix's row or column names, and draws them in the trees' order. Each
track is, in order of preference:

- the data frame
  [`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) kept with the
  chart (`"maidr_annotations"`), matched as pheatmap matches it – exact
  for a numeric variable and a categorical one alike;

- for a categorical variable, the level each colour stands for in the
  annotation legend, when every colour of the legend is one level's –
  also exact.

A numeric track drawn by
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
directly, whose legend only shows a ramp and the ends of its range, and
a categorical one with no legend (`annotation_legend = FALSE`) are not
read, and a message (class `maidr_pheatmap_annotations`) names them.

With `kmeans_k` the rows are cluster centres, and pheatmap matches
`annotation_row` to their row names, the cluster numbers (the `1` of
`"Cluster: 1 Size: 12"`), not to the input's rows; so is it read. A data
frame of the input's rows matches no centre, and pheatmap stops before
drawing it.
