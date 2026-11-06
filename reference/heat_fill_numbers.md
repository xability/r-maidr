# A heatmap's fill values as the numbers its legend shows

Each cell holds a number. A category's is the one its legend shows,
where its name is a number, as `factor(score * 10)` shows 10, 20 and 30;
categories named otherwise, and colours as
[`after_scale()`](https://ggplot2.tidyverse.org/reference/aes_eval.html)
gives, have none. Read as numbers, a factor gave its level codes, and
the rest came out missing with a coercion warning.

## Usage

``` r
heat_fill_numbers(values)
```

## Arguments

- values:

  The fill's values

## Value

`values`, its categories as their numbers or, where any name is not one,
all missing
