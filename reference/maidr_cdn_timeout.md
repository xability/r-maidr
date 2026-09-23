# The time budget for the CDN version lookup, in seconds

The `maidr.cdn_timeout` option, then the `MAIDR_CDN_TIMEOUT` environment
variable, then 3 seconds. A value that is not a positive number warns
once and the default applies – `0` does not mean "skip the lookup"; that
is `maidr.cdn_version = "latest"` or `"bundled"`. A value outside 0.1 to
30 seconds warns once and is clamped: below the floor every lookup would
time out, and above the ceiling a value meant as milliseconds would hang
a render.

## Usage

``` r
maidr_cdn_timeout()
```

## Value

A number of seconds in `[0.1, 30]`
