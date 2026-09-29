# The names of a chart's groups, in the order lattice numbers them

[`panel.superpose()`](https://rdrr.io/pkg/lattice/man/panel.superpose.html)
numbers groups over the levels of a factor, or the sorted unique values
of anything else, across the whole chart; the `.group.<k>` in a grob's
name indexes this vector. A level no panel draws keeps its number.

## Usage

``` r
lattice_group_levels(plot)
```

## Arguments

- plot:

  A trellis object

## Value

Character vector, or `NULL` when the chart has no groups.
