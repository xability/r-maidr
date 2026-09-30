# Whether a heatmap source column can be coded by level

Only where [`match()`](https://rdrr.io/r/base/match.html) against the
levels agrees with the `==` the cell lookup is defined by: a factor, or
a plain character, number or logical. Any other class could give `==` a
meaning of its own.

## Usage

``` r
heat_codable(values)
```

## Arguments

- values:

  A source column

## Value

`TRUE` when
[`heat_level_codes()`](https://r.maidr.ai/reference/heat_level_codes.md)
may code it
