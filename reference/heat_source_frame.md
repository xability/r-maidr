# The data a heatmap layer drew its tiles from, one column per aesthetic

ggplot2 evaluates each aesthetic in the data the layer draws, its own
`data` or else the plot's (`Layer$layer_data()`), under the layer's
mapping and, unless `inherit.aes = FALSE`, the plot's. So
`aes(fill = score * 2)` draws each tile from twice its score. Each was
looked up instead as a column named after its mapping: "score \* 2"
names none, so every cell was read missing, and an expression for `x` or
`y`, as `factor(month, levels = month.abb)`, or a layer drawn from data
of its own, stopped the reading.

## Usage

``` r
heat_source_frame(plot, layer_index)
```

## Arguments

- plot:

  The ggplot2 object

- layer_index:

  The layer's index in `plot$layers`

## Value

A list: `data`, the layer's data with each tile's x, y and fill in the
columns `.maidr_heat_x`, `.maidr_heat_y` and `.maidr_heat_fill`; and
`fill_label`, the fill's name as ggplot2 labels it ("score \* 2"), or
`NULL` when the fill is not mapped

## Details

An `x` or `y` the layer does not map is read from the data's first or
second column, as it was before, and as missing where the data has no
such column. A fill the layer does not map is read as missing: its tiles
are all drawn in one colour, so no column of the data is what they show.
It was read from the data's third column, whatever that held. An
aesthetic that cannot be evaluated against the layer's data, or is no
vector there, is read as missing too. An
[`after_stat()`](https://ggplot2.tidyverse.org/reference/aes_eval.html)
of a variable the stat computes names no column of it, as
`after_stat(group)` does, or names a function: `after_stat(density)` is
[`stats::density()`](https://rdrr.io/r/stats/density.html) there, which
stopped the reading. A fill of categories is read by the numbers its
legend shows, as `factor(score * 10)` shows 10, 20 and 30, and as
missing where the names are not numbers, as `fill = grade` and the
colours
[`after_scale()`](https://ggplot2.tidyverse.org/reference/aes_eval.html)
gives: a factor was read as its level codes.
