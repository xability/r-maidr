# Resolve the printed label for a positional axis

The name ggplot2 prints beside the x or y axis, which is the name a
reader needs in order to know what the numbers are. A
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) override
wins, then the layer's own mapping, then the plot's – the same chain
[`resolve_legend_label()`](https://r.maidr.ai/reference/resolve_legend_label.md)
walks for a legend title, because it is the same chain ggplot2 walks.

## Usage

``` r
positional_axis_label(plot, built = NULL, aes_name = "x", layer_index = NULL)
```

## Arguments

- plot:

  The ggplot object

- built:

  Built plot from
  [`ggplot2::ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html),
  or NULL to build one on demand

- aes_name:

  `"x"` or `"y"`

- layer_index:

  Index of the layer whose mapping takes precedence, or NULL to consult
  only the plot-level mapping

## Value

Character scalar, never NULL

## Details

The difference from the legend case is only what to do when none of them
answers. A legend that has no title should have none; a positional axis
always has one printed on the chart, so the aesthetic name is emitted
rather than nothing. That is a poor label, but it is a label, and the
alternative is a number announced with no name at all.

[`resolve_legend_label()`](https://r.maidr.ai/reference/resolve_legend_label.md)'s
documented caution – that
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) records a
title even for an unmapped aesthetic, so only ask about one the layer is
grouped by – does not apply here. A layer with no x or y mapping has no
positions to announce and does not reach a processor that would ask.
