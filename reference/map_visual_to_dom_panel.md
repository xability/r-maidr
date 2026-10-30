# The gtable panel drawn at a facet panel's place in the grid

ggplot2 reports where it lays each facet panel out as `ROW` and `COL` in
`built$layout$layout`, and names the panels of the gtable it draws
`panel-<a>-<b>`. What `a` and `b` count is not the row and the column,
and differs between facets and releases. ggplot2 3.4.4 and 3.5 name a
[`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html)
panel `panel-<row>-<col>`, but write the
[`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
names in an order that matches no grid: a 2 x 2 wrap is
`panel-<row>-<col>`, a 2 x 3 one has `panel-3-1` in the first row,
second column. ggplot2 4.0 names a wrap's panels `panel-<col>-<row>`.
Reading the name as the column- major position of the panel, as this
did, gave each 2 x 2 wrap and grid the two off-diagonal panels each
other's names, and most panels of a grid that is not square another
panel's name, so their selectors named the marks of another panel: the
highlight lit the other panel's marks, and maidr.js, which places a
subplot where its first mark is drawn, put the subplots out of order.

## Usage

``` r
map_visual_to_dom_panel(panel_info, gtable)
```

## Arguments

- panel_info:

  Panel information from layout

- gtable:

  Gtable object

## Value

Gtable panel name or NULL if not found

## Details

What every release keeps is where a panel is drawn: its row and column
in the gtable's layout, `t` and `l`. A panel's rank among the distinct
`t` of the panels is its row, and its rank among the distinct `l` its
column, whatever the gtable calls it. A place no panel is drawn at names
none: guessing at another panel would hand the layer that panel's marks,
as
[`find_gtable_panel_grob()`](https://r.maidr.ai/reference/find_gtable_panel_grob.md)
declines to.
