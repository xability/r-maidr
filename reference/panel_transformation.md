# The transformation applied to one axis of a built plot

The transformation applied to one axis of a built plot

## Usage

``` r
panel_transformation(built, axis = "x", panel_id = NULL)
```

## Arguments

- built:

  Built plot from
  [`ggplot2::ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)

- axis:

  `"x"` or `"y"`

- panel_id:

  Panel index for faceted plots, or NULL for the first

## Value

The transformation object, or NULL when there is none to undo
