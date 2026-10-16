# The name the drawn cells of a pheatmap are exported under

[`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) draws its cells
as one rect grob with a generated name (`GRID.rect.<n>`), which changes
from one session to the next. It is renamed to this before drawing
([`pheatmap_name_cells()`](https://r.maidr.ai/reference/pheatmap_name_cells.md)),
so each cell is the SVG element `#maidr-pheatmap-cells.1.<k>`.

## Usage

``` r
PHEATMAP_CELLS_GROB
```
