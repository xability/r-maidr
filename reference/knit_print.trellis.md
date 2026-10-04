# Custom knit_print Method for lattice (trellis) Objects

Converts a trellis object a chunk returns to an accessible MAIDR chart,
as
[`knit_print.ggplot()`](https://r.maidr.ai/reference/knit_print.ggplot.md)
does for a ggplot object: inline in an HTML page, in its own iframe in
other HTML output, and as lattice draws it in any other output format. A
chart knitr prints for a chunk is one of the chunk's figures, drawn by
lattice, and the chart is shown in its place – unless lattice draws it
onto a page a `print(more = TRUE)` left open, whose figure stays
knitr's. One the chunk's code asks `knit_print()` for itself is returned
as the chart's Markdown, or as an inline image when the chart cannot be
read.

## Usage

``` r
# S3 method for class 'trellis'
knit_print(x, options = list(), ...)
```

## Arguments

- x:

  A trellis object

- options:

  Chunk options from knitr

- ...:

  Additional arguments (ignored)

## Value

A knit_asis object holding the chart, or `NULL` (invisible) when the
chart is drawn natively

## Details

A chart the chunk prints itself – `print(p)`, lattice's idiom for a
chart inside a loop or a function – does not reach this method, since
knitr does not route an explicit print through `knit_print`; it is a
figure of the chunk all the same.
