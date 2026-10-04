# Print a ggplot with the original (non-MAIDR) print method

The print method [`print()`](https://rdrr.io/r/base/print.html) would
find without MAIDR: that of the chart's own class when it has one ahead
of ggplot2's – a patchwork's, which draws every plot of it where
ggplot2's draws the last alone – and ggplot2's otherwise.

## Usage

``` r
print_ggplot_natively(x)
```

## Arguments

- x:

  A ggplot object

## Value

NULL (invisible)
