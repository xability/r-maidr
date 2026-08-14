# Group hexagonal bins into lattice rows

A hex lattice staggers alternate rows by half a cell, which is what lets
the hexagons tessellate. Read as a grid of counted cells it is a
heatmap, but the stagger means a bin's column index is not its position
– bin 3 of one row and bin 3 of the next sit at different x – so the
frontend announces centres rather than indices and this returns the rows
rather than a rectangle.

## Usage

``` r
hexbin_lattice(built_data)
```

## Arguments

- built_data:

  A layer's computed data, carrying `x`, `y` and `count`, one row per
  drawn hexagon

## Value

A list with `data` (rows of bins, each a list of `x`, `y` and `count`)
and `order` (the built-data row behind each bin, in emission order)

## Details

Rows ascend in y, because the frontend's UPWARD steps to the *next* row
index, the same convention the heatmap follows. Within a row bins ascend
in x.

Rows are ragged and are left that way.
[`stat_binhex()`](https://ggplot2.tidyverse.org/reference/geom_hex.html)
emits only the bins that hold something, so the lattice is genuinely
uneven; padding it would put cells on the chart that were never drawn.

The returned `order` is the point of the function. It is the built-data
row behind each emitted bin, in emission order, and the selectors are
built from it – so the highlight follows the regrouping instead of
relying on the DOM happening to be in the same order.
[`stat_binhex()`](https://ggplot2.tidyverse.org/reference/geom_hex.html)
does emit its rows bottom-first today, which means that reliance would
pass; it would also be undetectable the moment it stopped, since a
hexbin announces centres and has no index to contradict.
