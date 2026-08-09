# How many gtable panels one patchwork leaf occupies

One for an ordinary leaf; one per facet cell for a faceted one; none for
a leaf patchwork has wrapped. Used to walk
[`find_patchwork_panels()`](https://r.maidr.ai/reference/find_patchwork_panels.md)
in step with the leaf list – a leaf that contributes no panel must not
consume one, or every leaf after it is described over somebody else's
panel.

## Usage

``` r
count_leaf_panels(leaf_plot)
```

## Arguments

- leaf_plot:

  A leaf of a patchwork composition

## Value

Integer count, 0 for a wrapped leaf
