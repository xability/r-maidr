# What kind of curve a layer is, in lattice's own words

[`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html)
draws two curves read as a type another of its curves is also read as:
the line through each x value's average (`type = "a"`) is a `line`, as
the line through the data is, and a loess, a spline and a regression
line are each a `smooth`. These are named as lattice's `smooth` argument
and [`?panel.xyplot`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html)
name them, so that two of them drawn for one group can be told apart
([`lattice_qualify_layer_names()`](https://r.maidr.ai/reference/lattice_qualify_layer_names.md)).

## Usage

``` r
lattice_layer_kind(layer, type)
```

## Arguments

- layer:

  A layer description from the adapter

- type:

  The type the layer was read as

## Value

`"average"`, `"loess"`, `"spline"` or `"regression"` for those curves;
`type` for anything else.
