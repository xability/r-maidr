# Extract scale mapping from built plot

Extracts the scale mapping from a built ggplot2 plot object. This
mapping converts numeric positions back to category labels.

## Usage

``` r
extract_scale_mapping(built)
```

## Arguments

- built:

  Built plot data from ggplot2::ggplot_build()

## Value

Named vector for scale mapping, or NULL if no mapping available
