# The cells of a levelplot panel

[`panel.levelplot()`](https://rdrr.io/pkg/lattice/man/panel.levelplot.html)
draws one cell per row of the panel – `x`, `y` and `z` are shared by
every packet, and each packet names its rows with `subscripts` – at the
positions `x` and `y` take on the axes.

## Usage

``` r
lattice_level_cells(args)
```

## Arguments

- args:

  The panel's arguments

## Value

A list with the panel's `x`, `y` and `z` over its rows, and the sorted
distinct positions `ux` and `uy`; NULL when the panel has no rows
