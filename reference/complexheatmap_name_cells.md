# Give the cells of a ComplexHeatmap body names the selectors can rely on

`draw_heatmap_body()` pushes a viewport named
`<name>_heatmap_body_<kr>_<kc>` for each slice and draws its cells there
as one rect, column by column, each column top to bottom, at the middles
of an even grid. A slice's rect is renamed only when that is what it is:
one rect per cell of the slice, at exactly those places. When any slice
has none – drawn as a raster image (`use_raster = TRUE`, which
'ComplexHeatmap' chooses itself for more than 2000 rows or columns), or
with `rect_gp = gpar(type = "none")` – no cell is named, and the chart
is read without highlighting.

## Usage

``` r
complexheatmap_name_cells(grob, heatmap)
```

## Arguments

- grob:

  The gTree the drawing was grabbed as

- heatmap:

  The `Heatmap` drawn, its row and column order set

## Value

A list: `grob`, with the cells renamed; `cells`, a list of the names
given, `[[kr]][[kc]]`, or NULL when the cells cannot be selected
