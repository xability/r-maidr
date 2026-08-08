# Extract layout from a single leaf ggplot

Mirrors the single-plot path in `Ggplot2PlotOrchestrator`: labels are
read from the BUILT plot first. ggplot2 v4 resolves derived labels only
while building – the stat-computed "count" of
[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html),
and the mapped column names – so an unbuilt `labels` holds nothing but
the explicit
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) overrides.

## Usage

``` r
extract_leaf_plot_layout(leaf_plot, leaf_built = NULL)
```

## Arguments

- leaf_plot:

  The ggplot object

- leaf_built:

  The leaf's built plot, or NULL when it is unavailable

## Value

Layout with title and axes
