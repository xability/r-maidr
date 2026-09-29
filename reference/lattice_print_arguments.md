# The arguments of a print, named as lattice's drawer matches them

[`print()`](https://rdrr.io/r/base/print.html) passes a trellis object's
arguments on as they were written, and `plot.trellis()` matches them as
R matches any call: by name, by a partial name, or by position.
`print(p, c(0, 0, 0.5, 1))` and `print(p, pos = c(0, 0, 0.5, 1))` place
the chart exactly as `print(p, position = c(0, 0, 0.5, 1))` does, and
read by their names alone they would open the viewer in the middle of a
composition.

## Usage

``` r
lattice_print_arguments(args)
```

## Arguments

- args:

  The arguments [`print()`](https://rdrr.io/r/base/print.html) was given
  besides the object.

## Value

The arguments named as `plot.trellis()` matches them, or `NULL` when
they do not match it at all.
