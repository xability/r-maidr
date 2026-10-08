# Whether a layer is the median line of a `median_hilow` ribbon

Such a line is read as the band's median, so it is not read again as a
line of its own.

## Usage

``` r
summary_band_folds_line(layer_index, plot_object)
```

## Arguments

- layer_index:

  Index of the layer in `plot_object$layers`

- plot_object:

  A ggplot object

## Value

TRUE or FALSE
