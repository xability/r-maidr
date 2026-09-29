# The id of an exported grob, escaped for a CSS selector

The exporter writes a grob named `N` as `<g id="N.1">`, the `.1`
counting draws of that name. lattice grob names can hold spaces as well
as dots –
[`panel.densityplot()`](https://rdrr.io/pkg/lattice/man/panel.densityplot.html)
names its rug `density rug.x` – so every character outside
`[A-Za-z0-9_-]` is escaped, not only the dots.

## Usage

``` r
lattice_css_id(grob_name)
```

## Arguments

- grob_name:

  The grob's name

## Value

The escaped id of the grob's `<g>`.
