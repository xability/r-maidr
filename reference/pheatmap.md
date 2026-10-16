# Draw a clustered heat map with pheatmap, keeping its values for maidr

A wrapper of
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
that [`library(maidr)`](https://github.com/xability/r-maidr) puts on the
search path. It calls the original with every argument unchanged, draws
exactly what it draws and returns what it returns, with one addition:
the matrix the chart was drawn from, kept with the result so that
[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) announce each
cell's exact value.

## Usage

``` r
pheatmap(mat, ...)
```

## Arguments

- mat:

  The numeric matrix to draw, as
  [`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
  takes it

- ...:

  Every other argument of
  [`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html),
  passed on unchanged

## Value

What
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
returns, invisibly, with the drawn matrix as its `"maidr_matrix"`
attribute

## Details

[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
returns its trees and its drawing but not its matrix. Without this
wrapper – a chart drawn by a call to
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
by name, before maidr was loaded, or with 'pheatmap' attached after
maidr, which then masks this function – maidr can only read each cell
back from its colour, to within one band of the legend, and says so.

The matrix kept is the one drawn: the input after `scale = "row"` or
`"column"`, computed as pheatmap computes it; the k-means centres with
`kmeans_k`; in the order of the row and column trees.

## Attach order

Attach 'pheatmap' *before* maidr, or call `maidr::pheatmap()`:

    library(pheatmap)
    library(maidr)

## See also

[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md), which read
the result.

## Examples

``` r
if (requireNamespace("pheatmap", quietly = TRUE)) {
  m <- matrix(rnorm(20), 4, 5, dimnames = list(letters[1:4], LETTERS[1:5]))
  p <- maidr::pheatmap(m, silent = TRUE)
  maidr::save_html(p, file = tempfile(fileext = ".html"))
}
```
