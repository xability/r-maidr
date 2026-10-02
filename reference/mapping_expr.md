# A mapped expression as ggplot2 names it

The expression a mapping plots, with what ggplot2 leaves out of the
names it gives mappings taken out too (its internal `make_labels()`):
the stage it is evaluated at (`after_stat(density)`,
`stage(hwy, after_stat = density)`), the older spellings of a computed
variable (`stat(density)`, `..density..`) and the `.data` pronoun
(`.data$hwy`, `.data[["hwy"]]`), wherever they sit.

## Usage

``` r
mapping_expr(mapping)
```

## Arguments

- mapping:

  A quosure or expression from
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), or NULL

## Value

The expression, or NULL
