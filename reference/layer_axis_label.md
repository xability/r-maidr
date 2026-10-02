# The label a ggplot2 layer's values are read under on a positional axis

The axis title –
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html), or the
name ggplot2 gave the axis – unless the layer maps the aesthetic itself
and another layer read beside it puts something else on that axis. Only
then is the axis title no description of this layer in particular, and
the layer is named for what it plots:
`geom_col(aes(y = sales)) + geom_line(aes(y = target))` reads "sales"
and "target". A layer's own mapping that every other layer agrees with,
or that no other layer has, is what the axis title already describes, so
a one-layer plot keeps its
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) title
(#349).

## Usage

``` r
layer_axis_label(plot, layer_index, aes_name, axis_label)
```

## Arguments

- plot:

  The ggplot object

- layer_index:

  Index of the layer being read

- aes_name:

  `"x"` or `"y"`

- axis_label:

  The axis title from the plot's layout

## Value

Character scalar

## Details

Layers are compared by what they plot once ggplot2's own spellings are
taken out (see
[`mapping_expr()`](https://r.maidr.ai/reference/mapping_expr.md)), so
`aes(y = after_stat(density))` on a histogram agrees with a
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
beside it, which plots `after_stat(density)` without being asked to.
Where it is named for itself, the layer is named as ggplot2 would name
it – "density", never "after_stat(density)". Decoration maidr does not
read (see
[`layer_is_decoration()`](https://r.maidr.ai/reference/layer_is_decoration.md))
takes no part: an
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
arrow does not make a one-layer chart a two-layer one.
