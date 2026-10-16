# Whether a rect grob is the cells of an `nr` by `nc` slice

One rect per cell, column by column and each column top to bottom: the
`k`-th at the middle of row `(k - 1) %% nr + 1` from the top and column
`(k - 1) %/% nr + 1` from the left, in npc of the slice's viewport.

## Usage

``` r
complexheatmap_rect_is_cells(rect, nr, nc)
```

## Arguments

- rect:

  A rect grob

- nr, nc:

  The slice's number of rows and columns

## Value

TRUE when the rect draws exactly those cells, in that order
