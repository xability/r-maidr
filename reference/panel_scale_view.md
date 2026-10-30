# The view of the scale that maps an aesthetic, in one panel

A panel's `x` and `y` slots hold its horizontal and vertical axes, and
those are not always the `x` and `y` scales:
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
draws the x scale up the side, in the `y` slot. Read by slot, a flipped
scatter plot's month names went to its values, "value is Mar" for 3, and
its months were read as numbers.

## Usage

``` r
panel_scale_view(params, aesthetic)
```

## Arguments

- params:

  One panel's `panel_params`

- aesthetic:

  `"x"` or `"y"`

## Value

The view scale, or NULL where no slot's scale maps `aesthetic`
