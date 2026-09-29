# Rearrange an xyplot's rows so its spikes are drawn along the axis

`type = "h"` draws a spike per row, in the order of the rows, and joins
none of them, so that order is not one a reader can see – but the
frontend walks, pans and pairs a lollipop's marks in document order.
When nothing else the panel draws is joined in row order (`"l"`, `"b"`,
`"o"`), each packet's rows are sorted by position, x or
`horizontal = TRUE`'s y, which draws the same chart. Without groups a
style given as a vector is drawn one value per row, a missing row
included, and is sorted with the rows, as
[`lattice_prepare()`](https://r.maidr.ai/reference/lattice_prepare.md)
does for a bar.

## Usage

``` r
lattice_prepare_spikes(plot)
```

## Arguments

- plot:

  A trellis object drawn with
  [`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html)

## Value

The object, with each packet's rows in position order when it draws
spikes and nothing joined.
