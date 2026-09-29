# The high-level function a trellis object was made by

`p$call[[1]]` is the bare symbol of the generic whatever method built
the object – lattice sets it so – and
[`update()`](https://rdrr.io/r/stats/update.html) keeps it.
latticeExtra's `+ layer()` and [`c()`](https://rdrr.io/r/base/c.html)
rewrite it to `update`, and `doubleYScale()` to its own name, which is
how those compositions are told apart. A function that keeps the call as
it was written is named as it was called, so
[`latticeExtra::doubleYScale()`](https://rdrr.io/pkg/latticeExtra/man/doubleYScale.html)
is read through its `::`.

## Usage

``` r
lattice_high_level_name(plot)
```

## Arguments

- plot:

  A trellis object

## Value

The function's name, or `NA` when the call names none.
