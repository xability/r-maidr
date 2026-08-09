# Canonical axes for a categorical Base R chart

[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) all plot one
categorical axis against one measured axis, and none of them writes a
title unless the author does. Naming those axes for what they hold –
"Category" against "Value" – says what the numbers mean, where the
renderer's positional "X"/"Y" fallback only says where they sit, and it
claims nothing beyond the shape of the call. py-maidr's pie chart
defaults to the same two words.

## Usage

``` r
base_r_categorical_axes(args, horizontal = FALSE)
```

## Arguments

- args:

  Recorded argument list, or NULL

- horizontal:

  TRUE when the chart draws its value axis horizontally, which swaps
  which visual axis holds the categories

## Value

Canonical axes list
