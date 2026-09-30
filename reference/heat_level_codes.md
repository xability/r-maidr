# Each source row's level, for the heatmap cell lookup

Each source row's level, for the heatmap cell lookup

## Usage

``` r
heat_level_codes(values, levels)
```

## Arguments

- values:

  A source column accepted by
  [`heat_codable()`](https://r.maidr.ai/reference/heat_codable.md)

- levels:

  The axis levels

## Value

Integer vector: the level each value equals, `0` for none and `NA` for a
missing value, which compares `NA` against every level
