# The text ggplot2 draws for one level

The missing level reads as the two characters "NA", which is what is
printed on its axis tick and in its legend key, so the announcement
names the same category a sighted reader is looking at. A level that is
literally the string "NA" reads the same way and is a different level:
two categories, two ticks, both saying "NA", which is what ggplot2
draws.

## Usage

``` r
level_label(level)
```

## Arguments

- level:

  One level from
  [`discrete_level_order()`](https://r.maidr.ai/reference/discrete_level_order.md)

## Value

A length-1 character string, never `NA`
