# The rows of a panel that belong to one group

[`panel.superpose()`](https://rdrr.io/pkg/lattice/man/panel.superpose.html)
draws each group from the panel's rows whose group is that level,
keeping the rows' order, so these are the rows behind a `.group.<k>`
grob, in the order its marks were drawn.

## Usage

``` r
lattice_group_rows(args, group)
```

## Arguments

- args:

  The panel's arguments, as its panel function received them

- group:

  The group's number (see
  [`lattice_group_levels()`](https://r.maidr.ai/reference/lattice_group_levels.md)),
  or NA for an ungrouped panel

## Value

Logical vector over the panel's rows.
