# Check a configured CDN lookup budget and clamp it

Check a configured CDN lookup budget and clamp it

## Usage

``` r
maidr_bound_cdn_timeout(value, source)
```

## Arguments

- value:

  The setting as given

- source:

  What the setting is called, for the warning

## Value

A number of seconds in `[0.1, 30]`
