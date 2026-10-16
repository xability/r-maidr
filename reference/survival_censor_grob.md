# The marks at the censored times, on the curve

The marks at the censored times, on the curve

## Usage

``` r
survival_censor_grob(data, panel_params, coord, shape, size)
```

## Arguments

- data:

  The panel's rows

- panel_params, coord:

  The panel's, as handed to `draw_panel()`

- shape, size:

  The marks' plotting character and size, in ggplot2's units

## Value

A points grob, or NULL when no row is censored
