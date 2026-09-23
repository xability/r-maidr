# Ask the resolvers which maidr.js version `latest` is

Tries jsDelivr's data API, then the npm registry, within one shared time
budget: each request gets whatever the budget has left, and curl
enforces it as a limit on the whole transfer, name resolution included.
Never raises and never warns – a failed lookup must not fail a render –
so every failure, whether the network, an HTTP status, or an answer that
is not JSON or not a version, is `NULL`.

## Usage

``` r
maidr_fetch_latest_cdn_version(budget)
```

## Arguments

- budget:

  Seconds for the whole lookup

## Value

A semantic version, or `NULL`
