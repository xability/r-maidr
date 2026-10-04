# The axis titles `plot.default()` writes for a recorded `plot()` call

The axis titles
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html) writes
for a recorded
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call

## Usage

``` r
plot_default_axis_titles(plot_call)
```

## Arguments

- plot_call:

  A recorded [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  call

## Value

List with `x` and `y`, or an empty list when the call did not reach
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html)
