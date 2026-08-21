# Does a layer's curve land in the panel's auto-named polyline population?

`layer_polyline_grobs()` keeps every polyline that no *geom-named* tree
claims, so the population it returns is "layers that draw a BARE
polyline" – which is not the same set as "layers typed line".
[`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
is typed `smooth` and draws one anyway: `GeomFunction` inherits
`GeomPath$draw_panel()`, which returns a `polylineGrob` with nothing
named around it, while `GeomSmooth` and `GeomDensity` wrap theirs in
`geom_smooth.gTree` / `geom_density.gTree` and are skipped whole.

## Usage

``` r
layer_draws_bare_polyline(layer, type)
```

## Arguments

- layer:

  A ggplot2 layer.

- type:

  The layer type the adapter detected for it.

## Value

`TRUE` when the layer draws a bare, auto-named polyline.

## Details

Counting only the line-ish types therefore counted a population one
smaller than the one being indexed, and a
[`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
drawn *before* a
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
handed the line the function's curve to highlight (#204). Both charts
read correctly the whole time, which is the highlight-only shape
xability/maidr#814 names.
