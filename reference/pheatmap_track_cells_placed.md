# Whether a pheatmap's annotation rects are one per value, in drawn order

[`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) draws a side's
tracks as one rect per value, variable by variable: a column track's
left to right, each variable one step further from the matrix (up), a
row track's top to bottom, each one step further (left). Measured in a
scratch viewport, every rect must be where that puts it, so the `k`-th
rect is the cell its selector names.

## Usage

``` r
pheatmap_track_cells_placed(grob, count, variables, side)
```

## Arguments

- grob:

  The side's rect grob

- count:

  The number of rows or columns of the matrix

- variables:

  The number of tracks on the side

- side:

  `"row"` or `"col"`

## Value

TRUE or FALSE
