# Undo a lattice log scale

lattice stores and draws a log-scale axis in log units; `log = TRUE`
means base 10 and `"e"` the natural logarithm.

## Usage

``` r
lattice_untransform(values, log)
```

## Arguments

- values:

  Numeric values in the units lattice drew them in

- log:

  The axis' `log` scale component

## Value

The values on the data's own scale.
