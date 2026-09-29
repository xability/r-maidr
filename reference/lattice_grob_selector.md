# A selector for the shapes one lattice grob drew

A selector for the shapes one lattice grob drew

## Usage

``` r
lattice_grob_selector(grob_name, element)
```

## Arguments

- grob_name:

  The grob's name

- element:

  The SVG element its shapes are exported as: `use` for points,
  `polyline` for lines and segments, `rect`, `polygon`

## Value

A selector string.
