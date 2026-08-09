# Is a set of resolved coordinates usable for an axis grid?

[`grDevices::xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html)
coerces whatever it is given, so categorical coordinates come back as
all-`NA` numerics rather than as an error. Those are worse than the raw
input: [`range()`](https://rdrr.io/r/base/range.html) on them yields
infinities and a warning, where the raw character vector is simply
rejected as non-numeric.

## Usage

``` r
usable_xy_coords(coords)
```

## Arguments

- coords:

  Value returned by
  [`grDevices::xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html),
  or NULL

## Value

TRUE when both axes carry at least one finite value
