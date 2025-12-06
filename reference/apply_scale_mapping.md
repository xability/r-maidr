# Apply scale mapping to convert numeric positions to category labels

In faceted plots, ggplot2 converts categorical x-values to numeric
positions (1, 2, 3, ...) for efficiency. This function converts them
back to the original category labels using the scale mapping.

## Usage

``` r
apply_scale_mapping(numeric_values, scale_mapping)
```

## Arguments

- numeric_values:

  Vector of numeric x positions from built plot data

- scale_mapping:

  Named vector mapping positions to labels (e.g., c("1" = "A", "2" =
  "B"))

## Value

Vector of category labels
