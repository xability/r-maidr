# Whether an object is a plot maidr renders from the object itself

A ggplot2 object or a lattice (trellis) object. Base R charts are not
objects: they are recorded as they are drawn, and
[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) take them
with no argument.

## Usage

``` r
is_maidr_plot_object(x)
```

## Arguments

- x:

  Any object

## Value

TRUE for a ggplot2 or trellis object
