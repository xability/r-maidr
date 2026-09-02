# The `height` a recorded `barplot()` call draws

[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) reads its
data from `height`, which is its first formal. The recorder names
positional dots but leaves the dispatch argument as the caller wrote it,
so `height` arrives unnamed when it was passed by position and named
when it was not – and `barplot(beside = TRUE, height = m)` put `beside`
in the first slot, where every reader used to look.

## Usage

``` r
recorded_barplot_height(args)
```

## Arguments

- args:

  Recorded argument list

## Value

The height vector or matrix, or NULL
