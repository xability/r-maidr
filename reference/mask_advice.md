# Advice shown when an attached package masks one of maidr's wrappers

Shared by `.onAttach`, the attach hooks and the "No Base R plots
detected" errors so the wording stays in one place.

## Usage

``` r
mask_advice(package)
```

## Arguments

- package:

  Name of the package, as in
  [WRAPPED_SUGGESTS](https://r.maidr.ai/reference/WRAPPED_SUGGESTS.md).

## Value

A single advice string.
