# Recursively extract leaf ggplots in patchwork addition order

The order matches panel discovery order in \[find_patchwork_panels()\]
(patches first, then the plot carried by the patchwork object itself),
which is how leaves are paired with panels.

## Usage

``` r
extract_patchwork_leaves(node)
```

## Arguments

- node:

  Patchwork node or ggplot object

## Value

List of leaf ggplot objects
