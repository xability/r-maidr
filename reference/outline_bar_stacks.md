# Draw an invisible rect over each stacked bar

`geom_bar(stat = "identity")` and
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
draw a category's rows as a stack of rects, one per row, which reads as
one bar when nothing tells the segments apart. maidr.js highlights a bar
through one element, so each stack is given one: a rect spanning its
segments, with no fill and no outline, so the drawing is unchanged. The
rect grob is wrapped in a gTree with these rects after it; the grob
keeps its name, so its rects keep their ids.

## Usage

``` r
outline_bar_stacks(grob, stacks)
```

## Arguments

- grob:

  A grob, gTree, gList, or gtable (or NULL)

- stacks:

  The stacks from
  [`take_bar_stacks()`](https://r.maidr.ai/reference/take_bar_stacks.md):
  each a list of `grob`, a rect grob's name, and `bars`, a list of the
  positions of each bar's rects in it.

## Value

The same tree with the outlines drawn after each stacked grob

## Details

A rect grob whose position and size are not all in one unit, or whose
rects the stacks do not index, is left alone: its bars then have no
highlight, which is what they had.
