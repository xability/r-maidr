# MAIDR's custom print method for ggplot objects

When MAIDR interception is enabled, this renders ggplot objects in the
MAIDR interactive viewer. For unsupported plots, it falls back to the
original ggplot2 rendering.

## Usage

``` r
maidr_print_ggplot(x, newpage = is.null(vp), vp = NULL, ...)
```

## Arguments

- x:

  A ggplot object

- newpage:

  Draw on a new page?

- vp:

  Viewport to draw in

- ...:

  Additional arguments passed to the print method

## Value

Invisible ggplot object
