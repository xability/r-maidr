# Run MAIDR Example Plots

Launches example plots demonstrating MAIDR's accessible visualization
capabilities. Each example creates an interactive plot using
[`show()`](https://r.maidr.ai/reference/show.md).

## Usage

``` r
run_example(example = NULL, type = c("ggplot2", "base_r", "lattice"))
```

## Arguments

- example:

  Character string specifying which example to run. If `NULL` (the
  default), lists all available examples.

- type:

  Character string specifying the plot system to use: `"ggplot2"`
  (default), `"base_r"` or `"lattice"`.

## Value

Invisibly returns `NULL`. Called for its side effect of displaying an
interactive plot in the browser or listing available examples.

## Details

Available examples include various plot types such as bar charts,
histograms, scatter plots, line plots, boxplots, heatmaps, and more.

The `"lattice"` examples are a bar chart \[experimental\], a histogram
\[experimental\], a scatter plot \[experimental\], a box plot
\[experimental\] and a conditioned (faceted) scatter plot
\[experimental\]. Every chart maidr reads from 'lattice' is
experimental: none has been through a user study, and each may change
without a deprecation period. They need the 'lattice' package.

Each example script creates a plot and calls
[`show()`](https://r.maidr.ai/reference/show.md) to display it in your
default web browser with full MAIDR accessibility features including
keyboard navigation and screen reader support.

## See also

[`show()`](https://r.maidr.ai/reference/show.md) for displaying plots,
[`save_html()`](https://r.maidr.ai/reference/save_html.md) for saving to
file

## Examples

``` r
# List all available examples
run_example()
#> Available MAIDR examples:
#> ggplot2 examples:
#>   - bar
#>   - boxplot
#>   - candlestick
#>   - candlestick_with_ma_volume
#>   - dodged_bar
#>   - faceted
#>   - gantt
#>   - heatmap
#>   - histogram
#>   - line
#>   - multiline
#>   - patchwork
#>   - pie
#>   - roc
#>   - scatter
#>   - smooth
#>   - stacked_bar
#>   - step
#>   - violin
#> 
#> base_r examples:
#>   - bar
#>   - boxplot
#>   - dodged_bar
#>   - faceted_point
#>   - heatmap
#>   - histogram
#>   - line
#>   - multiline
#>   - pie
#>   - scatter
#>   - smooth
#>   - stacked_bar
#>   - step
#> 
#> lattice examples [experimental]:
#>   - bar
#>   - boxplot
#>   - faceted
#>   - histogram
#>   - scatter
#> 
#> Usage:
#>   run_example("bar")                 # Run ggplot2 bar chart
#>   run_example("histogram", "base_r") # Run Base R histogram
#>   run_example("boxplot", "lattice")  # Run lattice box plot [experimental]

if (interactive()) {
  # Run ggplot2 bar chart example
  run_example("bar")

  # Run Base R histogram example
  run_example("histogram", type = "base_r")

  # Run lattice box plot example [experimental]
  run_example("boxplot", type = "lattice")
}
```
