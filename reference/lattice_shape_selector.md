# A selector for the one shape at a position within a lattice grob

A selector for the one shape at a position within a lattice grob

## Usage

``` r
lattice_shape_selector(grob_name, index)
```

## Arguments

- grob_name:

  The grob's name

- index:

  The shape's position in the grob, 1-based, as the exporter numbers it:
  a shape that was not drawn keeps its number

## Value

A selector string.
