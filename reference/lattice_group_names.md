# The names a chart's key gives its groups

`auto.key` draws one entry per group, in the order lattice numbers them,
each labelled by its level unless the key's `text` says otherwise. That
text is what the legend shows a sighted reader, so the group is named by
it. A key given as `key =` is the user's own drawing and says nothing
about which group an entry stands for, so it names none.

## Usage

``` r
lattice_group_names(plot)
```

## Arguments

- plot:

  A trellis object

## Value

Character vector, or `NULL` when the chart has no groups.
