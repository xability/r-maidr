# The layout `plot.trellis()` will use: columns, rows and pages

A re-implementation of lattice's internal `compute.layout()`. `columns`
is 0 when lattice is left to choose the arrangement from the device's
aspect ratio at draw time; the page count never depends on the device.

## Usage

``` r
lattice_layout(plot)
```

## Arguments

- plot:

  A trellis object

## Value

Numeric `c(columns, rows, pages)`.
