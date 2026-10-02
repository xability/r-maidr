# Whether two mappings plot the same thing, as a string

The whole of
[`mapping_expr()`](https://r.maidr.ai/reference/mapping_expr.md)'s
expression, on one line, so that mappings which differ only past the end
of [`mapping_label()`](https://r.maidr.ai/reference/mapping_label.md)'s
name still differ.

## Usage

``` r
mapping_key(mapping)
```

## Arguments

- mapping:

  A quosure or expression from
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), or NULL

## Value

Character scalar, or NULL
