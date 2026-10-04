# MAIDR's custom print method for ggplot objects

When MAIDR interception is enabled, this renders ggplot objects in the
MAIDR interactive viewer. For unsupported plots, it falls back to the
original ggplot2 rendering, as it does for every plot printed while
knitr runs: a document's chart is a figure of its chunk, not a viewer's,
which knitr's plot hook shows as the chart (see
`draw_as_knit_figure()`).

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
