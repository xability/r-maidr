# Grid navigation bounds for one axis

`min`, `max` and `tickStep` for the axis named, read off the built
plot's panel parameters, or `NULL` when any of the three cannot be
determined – which leaves the axis with its label and no grid, the
graceful degradation \#158 settled on.

## Usage

``` r
axis_grid_info(built, axis = "x", panel_id = NULL)
```

## Arguments

- built:

  Built plot data

- axis:

  Character, either "x" or "y"

- panel_id:

  Panel index for faceted plots (optional, defaults to 1)

## Value

List with min, max, tickStep, or NULL

## Details

Lifted out of `Ggplot2PointLayerProcessor`, which still calls it, when
the rug processor came to need the same answer for the axis its ticks
stand on (#222). Two readings of one grid rule is how the two would
drift.
