# Compare two pre-release identifiers by semver precedence

Numeric identifiers compare numerically and sort below alphanumeric
ones; alphanumeric ones compare in ASCII order, whatever the locale's
collation.

## Usage

``` r
maidr_compare_identifier(x, y)
```

## Arguments

- x, y:

  Single identifiers

## Value

`-1`, `0` or `1`
