# A grob of a pheatmap's gtable, by its layout name

A grob of a pheatmap's gtable, by its layout name

## Usage

``` r
pheatmap_grob(gt, name)
```

## Arguments

- gt:

  The gtable [`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md)
  returned

- name:

  The layout name: `"matrix"`, `"row_names"`, `"col_names"`, `"legend"`,
  `"main"`, ...

## Value

The grob, or NULL when the chart has none of that name
