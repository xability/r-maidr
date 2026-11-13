# The data column a mapping names

A bare name, `aes(fill = group)`, names its column, and
[`factor()`](https://rdrr.io/r/base/factor.html) of one,
`aes(fill = factor(cyl))`, names the column it converts. Any other
mapping is an expression of the data, as `aes(fill = factor(wt %% 2))`,
and is named as a whole, as ggplot2 labels it: one string, which names
no column of the data. Unwrapped, the expression inside
[`factor()`](https://rdrr.io/r/base/factor.html) was one string per
part, "%%", "wt" and "2", and testing them against the data's names
stopped the reading with "'length = 3' in coercion to 'logical(1)'".

## Usage

``` r
mapping_column(mapping)
```

## Arguments

- mapping:

  A quosure or expression from
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), or NULL

## Value

One string, or NULL when there is no mapping
