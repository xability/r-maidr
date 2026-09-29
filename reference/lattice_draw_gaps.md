# Draw an unseen rectangle in each empty cell kept as a subplot

The frontend lays a figure out by measuring every subplot's panel on the
page, and one subplot it cannot measure sends the whole layout back to
array order, where Up moves down a grid whose rows run top first. An
empty cell has no panel, so it is given a rectangle of its own, with
neither fill nor border, over the cell a panel would have filled.
lattice places a panel in its page layout by its row and by its column
alone, so that cell is where a panel of its row meets a panel of its
column.

## Usage

``` r
lattice_draw_gaps(packets, prefix = LATTICE_PREFIX)
```

## Arguments

- packets:

  The packet matrix, `[row, column]`, 0 for an empty cell

- prefix:

  The grob-name prefix

## Value

NULL, invisibly. Draws on the current page.
