# Turn a CDN version setting into the version a URL names

Turn a CDN version setting into the version a URL names

## Usage

``` r
maidr_normalize_cdn_pin(value, source)
```

## Arguments

- value:

  The setting as given

- source:

  What the setting is called, for the warning

## Value

A semantic version, `"latest"`, or `NULL` (with a warning, once per
distinct value) when `value` is not usable
