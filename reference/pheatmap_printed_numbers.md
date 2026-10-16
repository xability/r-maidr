# Read the numbers a pheatmap printed in its cells

With `display_numbers = TRUE` each cell carries its value as drawn,
formatted by `number_format` (`"%.2f"`). A matrix the caller passed as
`display_numbers` may print anything – significance stars, say – and is
only taken when every label is a number or `NA`.

## Usage

``` r
pheatmap_printed_numbers(text, n, m)
```

## Arguments

- text:

  The matrix's text grob, or NULL

- n, m:

  The number of rows and columns of cells

## Value

An `n` by `m` numeric matrix, or NULL
