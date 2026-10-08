# The quantile rows of a `median_hilow` ribbon, or NULL when it is not one

The quantile rows of a `median_hilow` ribbon, or NULL when it is not one

## Usage

``` r
summary_band_rows(layer, plot_object, panel_id = NULL, pairs = NULL)
```

## Arguments

- layer:

  A ggplot2 layer

- plot_object:

  The plot the layer belongs to

- panel_id:

  Panel ID to scope the rows to (optional)

- pairs:

  The plot's
  [`summary_band_pairs()`](https://r.maidr.ai/reference/summary_band_pairs.md),
  or NULL to read them here

## Value

A data frame of `x`, `y`, `ymin`, `ymax`, `.width`, or NULL
