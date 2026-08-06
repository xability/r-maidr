# Augment every leaf of a patchwork composition

Mirrors \[extract_patchwork_leaves()\]'s traversal so the augmented tree
has the same leaf order. The result must be used for BOTH
\`patchwork::patchworkGrob()\` and \[process_patchwork_plot_data()\]:
grob names come from a global counter, so selectors computed against one
build cannot resolve against another.

## Usage

``` r
augment_patchwork_leaves(node)
```

## Arguments

- node:

  Patchwork node or ggplot object

## Value

The same structure with each leaf augmented
