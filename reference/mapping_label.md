# The name ggplot2 gives a mapped expression

The default title ggplot2 derives from a mapping:
[`mapping_expr()`](https://r.maidr.ai/reference/mapping_expr.md)'s
expression, deparsed and cut at the end of its first line, as
`make_labels()` cuts it. So `after_stat(density)`, `stat(density)`,
`..density..` and `.data$density` are all "density", and
`..count.. / sum(..count..)` is "count/sum(count)".

## Usage

``` r
mapping_label(mapping)
```

## Arguments

- mapping:

  A quosure or expression from
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), or NULL

## Value

Character scalar, or NULL when the mapping cannot be named

## Details

A name, not a key: two long expressions can share their first line.
Compare mappings with
[`mapping_key()`](https://r.maidr.ai/reference/mapping_key.md).
