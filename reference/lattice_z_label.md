# What the values of a levelplot are called

The colour key's title when it has one, otherwise the variable on the
formula's left-hand side.

## Usage

``` r
lattice_z_label(plot)
```

## Arguments

- plot:

  A trellis object

## Value

A string

## Details

The key is found by what draws it rather than by where it sits:
`colorkey = list(space = "left")` puts it on another side than the
right, and a legend of the chart's own can take the right instead.
