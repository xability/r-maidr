# Add the legend title as the z axis label for a grouped layer

A grouped layer emits a per-series `z` value (the group's name), and
MAIDR announces it as " is ". Without a z label the frontend falls back
to the generic word "Group", losing the legend title the plot actually
shows. Single-series layers emit no z value at all, so they get no z
label either.

## Usage

``` r
attach_series_group_axis(
  axes,
  plot,
  built,
  data,
  layer_index = NULL,
  aes_groups = list(c("colour", "color"))
)
```

## Arguments

- axes:

  Axes built so far

- plot:

  The ggplot2 object

- built:

  Built plot data (optional)

- data:

  The extracted layer data

- layer_index:

  Index of the layer being described

- aes_groups:

  Grouping aesthetics to probe, as documented on
  [`resolve_series_group_mapping()`](https://r.maidr.ai/reference/resolve_series_group_mapping.md)

## Value

The axes list, with z added when the layer is grouped
