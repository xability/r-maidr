# Apply processor plot augmentation to a single leaf ggplot

Some processors need extra geoms in the rendered SVG to hang selectors
on – violin injects a thin \`geom_boxplot()\` so the box-summary layer
has something to highlight. The single-plot path does this in
\`Ggplot2PlotOrchestrator\$process_layers()\`; leaves of a patchwork
need the same treatment before the composition is rendered.

## Usage

``` r
augment_leaf_plot(leaf_plot)
```

## Arguments

- leaf_plot:

  A ggplot object

## Value

The augmented ggplot (the input unchanged when nothing augments)
