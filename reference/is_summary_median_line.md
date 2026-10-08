# Whether a layer is a `stat_summary()` line of the median

`stat_summary(geom = "line", fun = median)`, or a `median_hilow` summary
drawn as a line, whose `y` is the median whatever its width.

## Usage

``` r
is_summary_median_line(layer)
```

## Arguments

- layer:

  A ggplot2 layer

## Value

TRUE or FALSE
