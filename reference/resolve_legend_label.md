# Resolve the legend title for a grouping aesthetic

Returns the title ggplot2 prints above the legend for a grouping
aesthetic, which is what the MAIDR payload emits as the z axis label. A
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) override
wins (ggplot2 stores it on the built plot's `labels`, normalising
`color` to `colour`); otherwise the mapped expression is used, with the
layer's own mapping taking precedence over the plot-level one. Returns
NULL when the aesthetic carries neither.

## Usage

``` r
resolve_legend_label(
  plot,
  built = NULL,
  aes_names = "fill",
  layer_index = NULL
)
```

## Arguments

- plot:

  The ggplot object

- built:

  Built plot from
  [`ggplot2::ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html),
  or NULL to build one on demand

- aes_names:

  Aesthetic names to try, in order. Pass spelling variants of one
  aesthetic (for example `c("colour", "color")`), never unrelated
  aesthetics.

- layer_index:

  Index of the layer whose mapping takes precedence, or NULL to consult
  only the plot-level mapping

## Value

Character scalar, or NULL when the aesthetic has no title

## Details

Callers are responsible for only asking about an aesthetic the layer is
actually grouped by:
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) records a
title even for an unmapped aesthetic, so an unguarded lookup would
invent a legend that the plot does not draw.
