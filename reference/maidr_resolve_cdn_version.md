# The latest published maidr.js version, looked up once per session

The first call asks the resolvers (see
[`maidr_fetch_latest_cdn_version()`](https://r.maidr.ai/reference/maidr_fetch_latest_cdn_version.md))
and caches the answer, a failure included, so a machine that cannot
reach them pays the time budget once rather than on every render. Reset
with
[`maidr_reset_cdn_cache()`](https://r.maidr.ai/reference/maidr_reset_cdn_cache.md).

## Usage

``` r
maidr_resolve_cdn_version()
```

## Value

A semantic version, or `NULL` when the lookup failed
