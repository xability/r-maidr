# The panel functions each supported high-level function draws with

A trellis object is read only while its panel function is the stock one
for the function that made it: the reading of each chart is written
against what that panel function draws, and a custom panel function can
draw anything, including exactly the same grobs as a stock one with
different meaning. `levelplot(useRaster = TRUE)` switches to
`panel.levelplot.raster`, which draws one image rather than cells, and
is left out for that reason.

## Usage

``` r
LATTICE_SUPPORTED_PANELS
```

## Details

[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a time
series draws with
[`panel.superpose()`](https://rdrr.io/pkg/lattice/man/panel.superpose.html),
or with
[`panel.superpose.plain()`](https://rdrr.io/pkg/lattice/man/panel.superpose.html)
when each series has a panel of its own; both draw each series with
[`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html),
and so the same grobs, as long as no `panel.groups` of the chart's own
replaces it – which
[`lattice_static_check()`](https://r.maidr.ai/reference/lattice_static_check.md)
refuses.
