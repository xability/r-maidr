# Run MAIDR Example Plots

Launches example plots demonstrating MAIDR's accessible visualization
capabilities. Each example creates an interactive plot using \`show()\`.

## Usage

``` r
run_example(example = NULL, type = c("ggplot2", "base_r"))
```

## Arguments

- example:

  Character string specifying which example to run. If \`NULL\` (the
  default), lists all available examples.

- type:

  Character string specifying the plot system to use. Either
  \`"ggplot2"\` (default) or \`"base_r"\`.

## Value

Invisibly returns \`NULL\`. Called for its side effect of displaying an
interactive plot in the browser or listing available examples.

## Details

Available examples include various plot types such as bar charts,
histograms, scatter plots, line plots, boxplots, heatmaps, and more.

Each example script creates a plot and calls \`show()\` to display it in
your default web browser with full MAIDR accessibility features
including keyboard navigation and screen reader support.

## See also

\[show()\] for displaying plots, \[save_html()\] for saving to file

## Examples

``` r
# List all available examples
run_example()
#> Available MAIDR examples:
#> ggplot2 examples:
#>   - bar
#>   - boxplot
#>   - dodged_bar
#>   - faceted
#>   - heatmap
#>   - histogram
#>   - line
#>   - multiline
#>   - patchwork
#>   - scatter
#>   - smooth
#>   - stacked_bar
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
#>   - scatter
#>   - smooth
#>   - stacked_bar
#> 
#> Usage:
#>   run_example("bar")                 # Run ggplot2 bar chart
#>   run_example("histogram", "base_r") # Run Base R histogram

if (interactive()) {
  # Run ggplot2 bar chart example
  run_example("bar")

  # Run Base R histogram example
  run_example("histogram", type = "base_r")
}
```
