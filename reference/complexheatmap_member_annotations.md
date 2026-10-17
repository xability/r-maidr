# Which heat map each annotation a list holds belongs to

An annotation added to a list with `+` or `%v%` (\`ht1 +
rowAnnotation(...)

- ht2\`) is drawn between heat maps and annotates the rows (or columns)
  they share. It is read with the heat map read before it in the list,
  or, when none is, the first read after it.

## Usage

``` r
complexheatmap_member_annotations(drawn, read)
```

## Arguments

- drawn:

  The `HeatmapList` the draw returned

- read:

  The positions in `drawn@ht_list` of the heat maps read

## Value

One entry per heat map read, a list of `before` and `after`, the
annotations it owns that are drawn before and after it
