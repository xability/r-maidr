# A heatmap's fill values as the numbers its legend shows

Each cell holds a number. A category's is the one its legend shows,
where its name is a number, as `factor(score * 10)` shows 10, 20 and 30.
Where a name is not one, as `fill = grade` shows "high", "low" and
"mid", a category is its place in the legend, 1 for the first: the
layer's z axis names each place
([`heat_level_format()`](https://r.maidr.ai/reference/heat_level_format.md)),
so the cell is read by its category's name, or by the label the legend
shows for it where a scale relabels it
([`heat_legend_labels()`](https://r.maidr.ai/reference/heat_legend_labels.md)),
numbers too. Where there is no legend to place them in, as for the
colours
[`after_scale()`](https://ggplot2.tidyverse.org/reference/aes_eval.html)
gives, they are missing. Read as numbers, a factor gave its level codes,
and the rest came out missing with a coercion warning; then categories
named otherwise were all read as missing.

## Usage

``` r
heat_fill_numbers(values, levels = NULL, labels = levels)
```

## Arguments

- values:

  The fill's values

- levels:

  The legend's categories in its order, or NULL where it has none

- labels:

  What the legend shows for each of `levels`

## Value

`values`, its categories as their numbers or as their places in
`levels`, with `labels` as the attribute `maidr_levels`; or, where any
name is not a number and there are no levels, all missing
