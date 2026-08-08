# Resolve the aesthetic that splits a layer into series

Mirrors ggplot2's precedence: the layer's own mapping wins over the
plot-level one. ggplot2 normalises `color` to `colour`, but both
spellings are probed defensively.

## Usage

``` r
resolve_series_group_mapping(
  plot,
  layer_index = NULL,
  aes_groups = list(c("colour", "color"))
)
```

## Arguments

- plot:

  The ggplot2 object

- layer_index:

  Index of the layer whose mapping takes precedence, or NULL to consult
  only the plot-level mapping

- aes_groups:

  List of aesthetic-name vectors, probed in order. Each element must
  hold spelling variants of ONE aesthetic (for example
  `c("colour", "color")`), never unrelated aesthetics: the winning
  element is handed to
  [`resolve_legend_label()`](https://r.maidr.ai/reference/resolve_legend_label.md),
  which documents that contract.

## Value

list with `aes` (the winning spelling variants, or NULL when nothing is
mapped) and `column` (the mapped column name, or "group" as a fallback)
