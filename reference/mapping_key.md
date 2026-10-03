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

## Details

Less the ways a category is drawn somewhere else on its own axis: a
change of type, and a category's position offset by a number.
`factor(cyl)` is `cyl`, `as.numeric(term) + 0.1` is `term` dodged by
hand, and `as.numeric(factor(class)) - 0.3` is `class` nudged beside its
boxes, so none of them is something else plotted on that axis. An offset
of anything else – `sales + 1` – is a different value, and stays one.
