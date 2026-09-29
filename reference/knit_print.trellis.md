# Custom knit_print Method for lattice (trellis) Objects

Converts a trellis object a chunk returns to an accessible MAIDR chart,
as
[`knit_print.ggplot()`](https://r.maidr.ai/reference/knit_print.ggplot.md)
does for a ggplot object: in its own iframe in HTML output, as an inline
image when the chart cannot be read, and as lattice draws it in any
other output format.

## Usage

``` r
knit_print.trellis(x, options = list(), ...)
```

## Arguments

- x:

  A trellis object

- options:

  Chunk options from knitr

- ...:

  Additional arguments (ignored)

## Value

A knit_asis object containing the iframe HTML or inline image

## Details

Only a chart the chunk returns reaches this method. One the chunk prints
itself – `print(p)`, lattice's idiom for a chart inside a loop or a
function – is drawn by lattice onto knitr's device and included as the
figure knitr records, since knitr does not route an explicit print
through `knit_print`. A Base R chart drawn later in the same chunk takes
that figure's place: the plot hook hands the first figure of a chunk
whose device recorded Base R calls to those calls.
