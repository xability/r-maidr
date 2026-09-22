# The grob a ggplot2 layer drew, found by its slot in the panel

ggplot2 lays a panel out as `grill`, a `zeroGrob`, then one grob per
layer in layer order, then the panel's border – so this layer's grob is
the one `index` places after that first blank. A search by grob name
cannot tell two layers of the same geom apart: two
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)s
in a panel are both `geom_rect.rect.N`, and a search that collects every
match hands each layer the other's bars as well as its own.

## Usage

``` r
find_layer_slot_grob(panel, index)
```

## Arguments

- panel:

  The panel grob, or NULL

- index:

  The layer's index in the plot, or NULL

## Value

The grob in the layer's slot, or NULL when the slot cannot be
established

## Details

`LayerProcessor$find_layer_grob_tree()` matches on the geom's own class,
and a
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
layer is `GeomCol` while the grob it draws is named after `geom_rect`,
so it does not serve here. Counting containers instead of slots does not
either – a
[`geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
layer occupies a slot and draws no container, so the counts stop lining
up.
