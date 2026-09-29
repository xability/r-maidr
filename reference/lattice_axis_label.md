# The label a reader should hear for an axis

What lattice draws, and otherwise the default it would have drawn. A
horizontal [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html),
[`bwplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) or
[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) draws no
title on its category axis (`ylab` is `NULL`), and the default – the
name of the variable – says what the categories are where the renderer's
generic "Y" would only say where they sit.

## Usage

``` r
lattice_axis_label(label, default = NULL)
```

## Arguments

- label:

  The `xlab` or `ylab` field

- default:

  The `xlab.default` or `ylab.default` field

## Value

A string, or `NULL`.
