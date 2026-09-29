# The display order of each conditioning variable's levels

What `plot.trellis()` calls `used.condlevels`: `index.cond` applied to
each variable's levels, the variables then permuted by `perm.cond`.

## Usage

``` r
lattice_used_levels(plot)
```

## Arguments

- plot:

  A trellis object

## Value

A list of integer vectors, one per conditioning variable.
