# The values a stat computed a heatmap's fill from

A grid a stat computes is coloured by what ggplot2 evaluates after the
stat, over what the stat computed: the layer's fill, or the plot's where
the layer inherits it, when ggplot2 evaluates it after the stat
([`heat_after_stat()`](https://r.maidr.ai/reference/heat_after_stat.md)),
and otherwise the stat's own, `after_stat(count)` for
[`geom_bin_2d()`](https://ggplot2.tidyverse.org/reference/geom_bin_2d.html)
and `after_stat(value)` for
[`stat_summary_2d()`](https://ggplot2.tidyverse.org/reference/stat_summary_2d.html).
The built data holds what the stat computed, so it is evaluated there.
The bins' counts were read whatever the fill was, as
`after_stat(density)`, under the fill's title; and the cells of
[`stat_summary_2d()`](https://ggplot2.tidyverse.org/reference/stat_summary_2d.html)
and of a density raster were read as missing.

## Usage

``` r
heat_stat_fill(layer, plot, data)
```

## Arguments

- layer:

  The heatmap's layer

- plot:

  The ggplot2 object

- data:

  The layer's built data, every panel's rows

## Value

A list: `values`, one number per row of `data`, `NA` where there is
none; and `label`, the fill's name as ggplot2 names it, or NULL where
the stat computes no fill

## Details

A fill the stat does not compute is read as missing: a constant, as
`stat_summary_2d(fill = "steelblue")` gives, or none, as on a density
raster that maps no fill, draws every tile in one colour; and ggplot2
drops a fill of the data's own columns from what such a stat draws.
