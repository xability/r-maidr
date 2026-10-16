# The confidence band beneath the curves, stepped as they are

One polygon per group from its rows with both bounds, filled with the
group's `fill` or, when none is mapped, its `colour`.

## Usage

``` r
survival_band_grob(groups, panel_params, coord, alpha)
```

## Arguments

- groups:

  The panel's rows, split by group and sorted by x

- panel_params, coord:

  The panel's, as handed to `draw_panel()`

- alpha:

  The band's opacity

## Value

A polygon grob, or NULL when no group has a band
