# Read the version out of a resolver's answer

Read the version out of a resolver's answer

## Usage

``` r
maidr_parse_resolver_response(body, field)
```

## Arguments

- body:

  The response body, JSON

- field:

  The top-level field that holds the version

## Value

A semantic version, or `NULL` when the answer holds none
