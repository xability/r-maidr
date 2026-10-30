# A chart's axes, titled as those of the plot it is drawn onto

A chart drawn onto a plot with `add = TRUE` (`shared_plots()`) draws
against that plot's axes and writes no axis title of its own, so R shows
the plot's: `hist(x, xlab = "Weight"); hist(y, add = TRUE)` titles the
second histogram's x axis "Weight", not "y", the title `hist(y)` draws
on a plot of its own, nor an `xlab` it was given.

## Usage

``` r
with_plot_axis_titles(axes, plot_axes)
```

## Arguments

- axes:

  The chart's canonical axes, or NULL

- plot_axes:

  The canonical axes the plot it is drawn onto was read with, the titles
  written after it included
  ([`with_margin_titles()`](https://r.maidr.ai/reference/with_margin_titles.md)),
  or NULL where that plot was not read

## Value

`axes`, its x and y axes titled as the plot's are, or untitled where the
plot's is; `axes` as given where the plot was not read
