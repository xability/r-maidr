# Give the cells of each annotation track names the selectors can rely on

`anno_simple()` draws each slice of a track in a viewport named
`annotation_<name>_<k>`, `k` the slice in drawn order, inside the
viewport `heatmap_<owner>` of the heat map or list annotation it belongs
to, as one rect: a column track's cells left to right, a row track's top
to bottom, each at the middle of an even grid. A slice's rect is renamed
only when that is what it is: one rect per cell, at those places, each
filled with the colour the track's colour mapping gives the cell's
value. A track drawn otherwise – runs of one level merged into one rect,
which `anno_simple()` does for a discrete track given a `gp` without
`col` – or one whose name another track of the same owner also has, so
its viewports cannot be told apart, is read without highlighting.

## Usage

``` r
complexheatmap_name_annotations(grob, tracks, heatmap, h = 1L)
```

## Arguments

- grob:

  The gTree the drawing was grabbed as

- tracks:

  The tracks, from
  [`complexheatmap_annotation_tracks()`](https://r.maidr.ai/reference/complexheatmap_annotation_tracks.md)

- heatmap:

  The `Heatmap` drawn, its row and column order set

- h:

  The heat map's place among those read, for the names given

## Value

A list: `grob`, with the cells renamed; `cells`, one entry per track, a
list of the names given by slice, or NULL when the track's cells cannot
be selected
