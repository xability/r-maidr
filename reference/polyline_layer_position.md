# Position (1-based) of a layer among the polyline-producing layers of a plot

`layer_polyline_grobs()` returns every polyline in the panel that no
geom-named grob tree claims, so the index used to pick one out has to be
counted over the same population.
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
/
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
/
[`tidyquant::geom_ma()`](https://business-science.github.io/tidyquant/reference/geom_ma.html)
(detected as `"line"`),
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
(detected as `"step"`) and
[`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html)
/
[`geom_density_2d()`](https://ggplot2.tidyverse.org/reference/geom_density_2d.html)
(detected as `"contour"`) each render one auto-named polyline grob per
layer, so all three types count. Counting only `"line"` layers would
index the wrong polyline for *every* layer of a plot that combines them
– and both charts would read correctly while outlining each other's
curves, which is the highlight-only failure xability/maidr#814 names.

## Usage

``` r
polyline_layer_position(plot, layer_index)
```

## Arguments

- plot:

  The ggplot2 object.

- layer_index:

  Index of the layer of interest in `plot$layers`.

## Value

The 1-based position, or NULL when the layer produces no polyline or
registry-based detection fails.
