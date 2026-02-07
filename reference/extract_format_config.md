# Extract Format Configuration from Built Plot

Extracts MAIDR format configuration from the scale objects in a built
ggplot2 plot. This looks for the `maidr_format` attribute attached by
the maidr label functions.

## Usage

``` r
extract_format_config(built)
```

## Arguments

- built:

  A built ggplot2 object from
  [`ggplot2::ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)

## Value

A list with `x` and/or `y` format configurations, or NULL if no format
config is found
