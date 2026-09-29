# The arguments a chart's `strip.custom()` strip was made with

`strip.custom(...)` returns a strip function that keeps its arguments in
its enclosure, as `args`, and hands them to
[`strip.default()`](https://rdrr.io/pkg/lattice/man/strip.default.html)
over the ones lattice passes – so a `factor.levels` given there is drawn
for every conditioning variable, indexed by the packet's level of it,
and a `var.name` indexed by the variable. The top strip wins over the
left.

## Usage

``` r
lattice_strip_args(plot)
```

## Arguments

- plot:

  A trellis object

## Value

A list, empty when neither strip was made by
[`strip.custom()`](https://rdrr.io/pkg/lattice/man/strip.default.html).
