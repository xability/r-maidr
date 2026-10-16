# Whether values agree with the colours their cells were drawn in

Each value must lie in the legend band of its cell's colour, give or
take `tolerance`; a value beyond the outermost breaks is drawn in the
end colour, so those two bands are open-ended. This is how a matrix kept
with the chart, or numbers printed in its cells, are known to be the
values the colours were drawn from – and not, say, p-values a caller
printed over them.

## Usage

``` r
pheatmap_values_agree(values, fill, bands, tolerance)
```

## Arguments

- values:

  A numeric matrix, the shape of `fill`

- fill:

  The cells' fill colours

- bands:

  The legend's bands, from
  [`pheatmap_legend_bands()`](https://r.maidr.ai/reference/pheatmap_legend_bands.md)

- tolerance:

  How far outside its band a value may lie

## Value

TRUE when every finite value agrees
