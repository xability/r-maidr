# The name the cells of one slice of a ComplexHeatmap body are exported under

`ComplexHeatmap` draws the cells of each slice of the body – one per
combination of row and column slice, `row_split`/`row_km` by
`column_split`/`column_km`, a single one without splits – as one rect
grob with a generated name (`GRID.rect.<n>`). Each is renamed to this
prefix followed by `-<kr>-<kc>`, its row and column slice in drawn
order, so each cell is the SVG element
`#maidr-complexheatmap-cells-<kr>-<kc>.1.<k>`.

## Usage

``` r
COMPLEXHEATMAP_CELLS_GROB
```
