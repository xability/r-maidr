# The name of the lattice panel function a panel is, or NA

`plot.trellis()` resolves a character panel with
[`get()`](https://rdrr.io/r/base/get.html) from inside the lattice
namespace, so a name means lattice's own function whatever the caller's
search path holds. A function object counts only when it is lattice's
own, [`identical()`](https://rdrr.io/r/base/identical.html) to it; any
closure is custom, even one that only calls a stock panel function.

## Usage

``` r
lattice_panel_name(panel)
```

## Arguments

- panel:

  The `panel` field of a trellis object

## Value

A panel function name, or `NA`.
