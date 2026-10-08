# Check the fan charts declared for an echarts4r widget

The rules are the ones maidr.js's own validator applies
(`isValidBands()` in its trace declarations), checked here so that a
mistake is an error in R, where the author is, rather than a warning in
a browser console nobody opens: a median named by a non-empty string, at
least one band, each naming a series with a `lower` level from 0 to
below 0.5 and an `upper` one above 0.5 to 1, fractions rather than
percentages, and the bands nested, each strictly inside the next wider
one.

## Usage

``` r
validate_percentile_bands(percentile_bands)
```

## Arguments

- percentile_bands:

  A fan – a list with `median` and `bands` – or a list of them.

## Value

A list of fans, each a list of `median`, `bands` (a list of
`list(series, lower, upper)`) and, when given, `title` and `name`, in
the shape maidr.js reads once serialised.
