# Every grob name in a tree, depth first

Shared with the box plot processor's own walk, which looks for the same
`graphics-plot-N-kind-M` names in the same tree shape.

## Usage

``` r
collect_grob_names(g)
```

## Arguments

- g:

  A grob, gList, gTree or gtable.

## Value

A character vector of names.
