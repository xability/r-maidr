# Count a page a knit starts: R's `before.plot.new` hook

[`plot.new()`](https://rdrr.io/r/graphics/frame.html) starts a page
unless it moves to the next panel of one (`par(mfrow = )`), which
`par("page")` tells before it does.

## Usage

``` r
knit_before_plot_new()
```

## Value

NULL (invisible)
