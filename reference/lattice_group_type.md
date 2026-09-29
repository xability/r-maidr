# The plot types one group of a panel is drawn with

[`panel.superpose()`](https://rdrr.io/pkg/lattice/man/panel.superpose.html)
draws every group with the whole `type` vector, unless
`distribute.type = TRUE`, when group `k` is drawn with the `k`-th type
alone – the vector recycled over the groups, so with three groups
`type = c("s", "l")` draws the third as a staircase again.

## Usage

``` r
lattice_group_type(args, group)
```

## Arguments

- args:

  The panel's arguments, as its panel function received them

- group:

  The group's number (see
  [`lattice_group_levels()`](https://r.maidr.ai/reference/lattice_group_levels.md)),
  or NA for an ungrouped panel

## Value

The `type` the group is drawn with, `NULL` when none was given.
