# The two-way contingency table a recorded call was handed, when it is one

[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
given the table itself, so the recorded call carries every number a
`mosaic` layer wants – the counts, the margins they imply, and the level
names from [`dimnames()`](https://rdrr.io/r/base/dimnames.html). Nothing
is inferred from the drawing.

## Usage

``` r
recorded_two_way_table(args)
```

## Arguments

- args:

  Recorded argument list, or NULL

## Value

A 2-D table with named margins, or NULL

## Details

Only a two-dimensional table is returned.
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
accepts three and more, splitting recursively, and a `mosaic` layer has
one category axis and one fill – so a deeper table has nowhere to put
its later dimensions and is declined rather than flattened into a
cross-classification the chart does not claim. A table with unnamed
margins is declined too: the levels are what a reader navigates by, and
positions are not levels.

Shared by the adapter's dispatch and the processor's extraction so the
two cannot disagree about which calls are readable.
