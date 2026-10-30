# The text of a facet panel's strips

A panel is named for its strips, which ggplot2 writes through the
facet's labeller:
`facet_grid(vs ~ am, labeller = labeller(vs = c("0" = "V-engine", "1" = "Straight")))`
writes "V-engine" where `vs` is 0, and `label_both` writes "cyl: 4". The
panels were named by the raw values instead, "0 & 1", which said neither
what the strips say nor which variable each number was.

## Usage

``` r
facet_strip_labels(panel_info, built, facet_groups)
```

## Arguments

- panel_info:

  Panel information from layout

- built:

  Built plot data

- facet_groups:

  The panel's facet values, from
  [`get_facet_groups()`](https://r.maidr.ai/reference/get_facet_groups.md)

## Value

Character vector of the panel's strip labels, or its values

## Details

The labeller is called as ggplot2 calls it, on the facet's own layout, a
grid's rows and columns apart, and the panel's line is taken from what
it returns. A facet with no labeller, a labeller that fails, or one that
gives no text for the panel names it by its values, as before.
