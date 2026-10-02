# What a ggplot2 layer plots on a positional axis

The layer's own mapping for the aesthetic, else the plot's when the
layer inherits it, else the value its stat computes by default – the
`after_stat(count)` a histogram plots on y without being asked to. NULL
when the layer plots nothing there, or a constant it was given as a
parameter.

## Usage

``` r
layer_position_mapping(plot, layer, aes_name)
```

## Arguments

- plot:

  The ggplot object

- layer:

  One of its layers

- aes_name:

  `"x"` or `"y"`

## Value

A quosure or expression, or NULL

## Details

A stat default named for the aesthetic itself –
[`stat_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)'s
`after_scale(y)`,
[`stat_qq_line()`](https://ggplot2.tidyverse.org/reference/geom_qq.html)'s
`after_stat(y)` – is NULL as well: it is the stat's output with no name
of its own, not a variable another layer could plot differently.
