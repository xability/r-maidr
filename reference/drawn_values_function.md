# A function that returns the values a plotted function was drawn at

Stands in for the function in a recorded `plot(f)` call; see
[`plot_function_values()`](https://r.maidr.ai/reference/plot_function_values.md).
Its environment holds those values alone, not the frame it was made in.

## Usage

``` r
drawn_values_function(y)
```

## Arguments

- y:

  The y values
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) drew

## Value

A function of `x` returning `y`
