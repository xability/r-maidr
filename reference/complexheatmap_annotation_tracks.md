# The simple annotation tracks drawn beside a ComplexHeatmap heat map

A track is one `SingleAnnotation` drawn by `anno_simple()` – what
`HeatmapAnnotation(df = ...)`, `rowAnnotation(df = ...)`, a bare vector
(`HeatmapAnnotation(type = x)`) and `anno_simple(x)` all make – holding
one value per column (a column annotation) or per row (a row annotation)
of the matrix. They are taken from the heat map's own `top_annotation`,
`bottom_annotation`, `left_annotation` and `right_annotation`, and from
the annotations of a list it owns
([`complexheatmap_member_annotations()`](https://r.maidr.ai/reference/complexheatmap_member_annotations.md)):
column tracks first, top to bottom, then row tracks, left to right, each
annotation's tracks in the order drawn.

## Usage

``` r
complexheatmap_annotation_tracks(heatmap, members = list())
```

## Arguments

- heatmap:

  The `Heatmap`, as drawn

- members:

  The list's annotations it owns, `before` and `after` it

## Value

A list: `tracks`, each a list with `name` (the annotation's name),
`owner` (the name of the heat map, or list annotation, whose viewport it
is drawn in), `label` (what it is called on the chart), `which`
(`"column"` or `"row"`), `annotation` (the `SingleAnnotation`) and
`values` (one per matrix column or row, in the matrix's order); and
`unread`, the names of the annotations not read

## Details

Any other annotation – `anno_barplot()`, `anno_points()`, `anno_text()`,
`anno_mark()` and the like, or an `anno_simple()` of a matrix – is drawn
and not read; its name is returned in `unread`.
