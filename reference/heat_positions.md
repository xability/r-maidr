# Where a heatmap layer takes its x and y from, in the plot's data

A heatmap is reordered before it is drawn, so its tiles come out in the
order the reading pairs them with (`reorder_layer_data()`). That is done
to the plot's data, and only where the tiles draw it as it is: a layer
with data of its own, or a function of the plot's, leaves it alone.

## Usage

``` r
heat_positions(layer, plot, data)
```

## Arguments

- layer:

  The heatmap's layer, or NULL

- plot:

  The ggplot2 object

- data:

  The plot's data

## Value

`list(x = , y = )`, each `list(column = )` or `list(values = )`, or NULL

## Details

Each position follows the mapping, the layer's or else the plot's unless
`inherit.aes = FALSE`. A column it names, as a bare name, `.data$x`,
`.data[["x"]]` or `.data[[var]]` where `var` holds the name, is given as
that column. Any other expression is given as what it evaluates to over
the data, a symbol that is no column (a variable of the caller's) among
them. A constant, as `aes(x = 1)` stores it, and `.data[[f()]]`, which
names its column only by calling `f()` again, give none: the data is
then left as it is.
