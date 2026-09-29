# Split a layer of curves no one x value joins into a layer per curve

The frontend moves Up and Down between the series of a line, step or
smooth layer only onto a series with a point at the very x the reader is
on. Grouped curves drawn over each group's own x values – the densities
of a grouped
[`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html), lines
through each group's own observations – may share none, and the reader
could then reach no series but the first. So a layer whose series have
no x value in common is split into one layer per series, named by its
group, which PageUp and PageDown reach whatever x the reader is on. A
layer whose series all pass through one x value is kept whole: from
there Up and Down reach each series, and compare them at every x they
share.

## Usage

``` r
lattice_split_series(layer)
```

## Arguments

- layer:

  A layer, as `process_layer()` returns it

## Value

A list of layers: `layer` alone, or one per series. A split layer keeps
`layer`'s id; the others have none yet.
