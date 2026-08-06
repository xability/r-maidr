# Has patchwork wrapped this leaf?

\`inset_element()\`, \`free()\` and \`wrap_elements()\` each prepend
their own class and place the plot in a gtable cell whose name is not a
plain "panel-N", so panel discovery never sees it. Test for the wrapper
rather than naming them, so one added later behaves the same.

## Usage

``` r
is_wrapped_leaf(leaf_plot)
```

## Arguments

- leaf_plot:

  A leaf of a patchwork composition

## Value

Logical
