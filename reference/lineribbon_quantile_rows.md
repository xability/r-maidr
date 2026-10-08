# The quantile rows a lineribbon layer draws, or NULL when they are not quantiles

`stat_lineribbon()` leaves `.width`, `.point` and `.interval` in the
built data. `geom_lineribbon()` drawn from a `median_qi()` summary does
not – they are columns of the layer's own data, which the built rows
follow one for one – so they are read from there when the built data
lacks them.

## Usage

``` r
lineribbon_quantile_rows(layer, plot_object, built_rows = NULL)
```

## Arguments

- layer:

  A ggplot2 layer

- plot_object:

  The plot the layer belongs to

- built_rows:

  The layer's built data, or NULL to build it here

## Value

A data frame of `x`, `y`, `ymin`, `ymax`, `.width`, or NULL

## Details

Declined – NULL – unless every row is a median with a quantile interval,
the layer draws one series (one row per x and width), the widths are
fractions of one, and the ribbon runs along x.
