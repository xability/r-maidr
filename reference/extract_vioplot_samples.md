# Split a vioplot call's arguments into one sample per violin

[`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes its
groups the way
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) does: as
separate vectors (`vioplot(a, b, c)`), as a single list or data frame,
or as a formula. Only the first two are read here; a formula call is
left for the caller to decline, because resolving it needs the
environment the call was made in and reconstructing that would be
guesswork.

## Usage

``` r
extract_vioplot_samples(args)
```

## Arguments

- args:

  The recorded call's arguments.

## Value

A named list of numeric vectors, one per violin, or an empty list.
