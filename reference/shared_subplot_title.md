# The title every panel of a figure carries

A figure of several panels that draws no title over them, with
`title(outer = TRUE)` or `plot_annotation()`, is still titled when every
one of its panels carries the same title: a `par(mfrow)` grid of four
plots each given `main = "Weekly sales"` is a page of weekly sales. A
panel's title is its first layer's, compared without the spaces around
it, which are not seen: R keeps them, so `"Sales"` and `"Sales "` are
one title on the page. A cell with no layers, where nothing was drawn,
is passed over, and an untitled panel leaves the figure untitled.

## Usage

``` r
shared_subplot_title(subplots)
```

## Arguments

- subplots:

  The figure's subplots, its grid flattened to a list

## Value

The title, or NULL when the panels' titles differ or one has none
