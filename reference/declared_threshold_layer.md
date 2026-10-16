# Build a declared volcano or Manhattan layer

[`ggplot2::layer()`](https://ggplot2.tidyverse.org/reference/layer.html)
directly, as [`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md)
calls it: the geom is what identifies the layer, and the thresholds are
consumed here rather than passed down, where
[`layer()`](https://ggplot2.tidyverse.org/reference/layer.html) would
drop them with `Ignoring unknown parameters`. The thresholds are kept on
the layer instance, which is an environment of its own, where
[`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) keeps its
`auc`.

## Usage

``` r
declared_threshold_layer(
  geom,
  thresholds,
  mapping,
  data,
  position,
  na.rm,
  show.legend,
  inherit.aes,
  ...
)
```

## Arguments

- geom:

  `GeomVolcano` or `GeomManhattan`

- thresholds:

  The list
  [`volcano_threshold_options()`](https://r.maidr.ai/reference/volcano_threshold_options.md)
  returned

- mapping:

  Aesthetics, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html):
  `x` (the effect size, such as a log2 fold change) and `y` (the
  significance, such as -log10 of the p value) are required. `label` may
  name each point (the gene) and `region` the group it belongs to; both
  are announced with the point. Every other point aesthetic (`colour`,
  `size`, `alpha`, ...) behaves exactly as it does there.

- data:

  The layer's data, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- position:

  Position adjustment, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- na.rm:

  If `FALSE` (the default), rows with missing values are removed with a
  warning.

- show.legend:

  Whether this layer is included in the legends.

- inherit.aes:

  If `FALSE`, the plot's default aesthetics are not inherited.

- ...:

  Other arguments passed to the layer, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  – except `stat`, which is fixed at `"identity"`: a declared layer is
  always drawn from the author's own points.

## Value

A ggplot2 layer
