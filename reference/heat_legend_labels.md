# What a heatmap's fill legend shows for each of its categories

A discrete fill scale's `labels`, as `scale_fill_discrete(labels = )` or
`scale_fill_manual(labels = )` gives them, replace the categories' names
in the legend, and a function of them, as `labels = toupper`, or
plotmath does too. Each category is named by the label shown for it; one
the legend gives none, as a category its `breaks` leave out, keeps its
name.

## Usage

``` r
heat_legend_labels(scale, levels)
```

## Arguments

- scale:

  The discrete fill scale, or NULL

- levels:

  The legend's categories in its order

## Value

A character vector as long as `levels`
