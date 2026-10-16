# A survminer figure's curve layer, redrawn with its band and marks

A child of the figure's own
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
layer – its data, mapping and fixed aesthetics – drawn by
`GeomSurvival`, with `censored` read from `n.censor`, the band from
`lower` and `upper` at the band layer's opacity and fill, and the marks
in the mark layer's shape and size.

## Usage

``` r
ggsurvplot_curve_layer(curve, band = NULL, marks = NULL)
```

## Arguments

- curve:

  The figure's
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  layer

- band:

  Its `GeomConfint` layer, or NULL

- marks:

  Its
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  layer of the censored times, or NULL

## Value

A layer
