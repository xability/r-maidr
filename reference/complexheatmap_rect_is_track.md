# Whether a rect grob is the cells of one slice of an annotation track

Whether a rect grob is the cells of one slice of an annotation track

## Usage

``` r
complexheatmap_rect_is_track(rect, fills, which)
```

## Arguments

- rect:

  A rect grob

- fills:

  The colour of each cell, in drawn order

- which:

  `"column"`, cells left to right, or `"row"`, top to bottom

## Value

TRUE when the rect draws one cell per colour, at the middles of an even
grid, filled with those colours
