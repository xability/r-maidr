# The value range each colour of a pheatmap's legend stands for

The legend draws one band per colour, from break to break, and labels
some breaks with their values (`grid.pretty()` of the range, or the
caller's numeric `legend_breaks`). Two labelled values fix the scale;
every band's breaks follow from where it is drawn. A colour drawn in
more than one band stands for the whole span of them.

## Usage

``` r
pheatmap_legend_bands(legend)
```

## Arguments

- legend:

  The gtable's `"legend"` grob, or NULL

## Value

A data frame with `colour` (normalised `#RRGGBBAA`), `lo` and `hi`, or
NULL when the legend is missing or its labels are not numbers that agree
with where they are drawn
