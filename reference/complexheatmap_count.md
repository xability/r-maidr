# The number of heat maps a ComplexHeatmap object holds

Annotations added to a list with `+` are not heat maps and are not
counted; their simple tracks are read with a heat map
([`complexheatmap_member_annotations()`](https://r.maidr.ai/reference/complexheatmap_member_annotations.md)).

## Usage

``` r
complexheatmap_count(plot)
```

## Arguments

- plot:

  A `Heatmap` or `HeatmapList`

## Value

An integer
