# Measure grid units in two viewports of different sizes

The positions pheatmap draws are sums of `npc` and `bigpts`, so two
measurements at different sizes tell any two of them apart.

## Usage

``` r
pheatmap_measure_units(units)
```

## Arguments

- units:

  A list of units, each named `"x"` or `"y"` for the axis it is measured
  along

## Value

A list of matrices in big points, one row per value of the unit and one
column per viewport
