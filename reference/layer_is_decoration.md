# Whether a ggplot2 layer is decoration maidr does not read

The layers `Ggplot2Adapter$detect_layer_type()` skips for what they are
rather than for what they drew: anything
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
built, text and labels,
[`geom_blank()`](https://ggplot2.tidyverse.org/reference/geom_blank.html)
and reference lines. A mapping ggplot2 marks "unlabelled" counts too,
since ggplot2 leaves it out of the axis titles it derives –
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)'s
literal `aes(x = x, y = y)` is one.

## Usage

``` r
layer_is_decoration(layer)
```

## Arguments

- layer:

  A ggplot2 layer object

## Value

TRUE when the layer is decoration
