# The CDN version a setting pins, if any

Reads the `maidr.cdn_version` option, then the `MAIDR_CDN_VERSION`
environment variable; an unset or blank option falls through to the
variable. A value that is not a usable pin warns once and is ignored, so
the latest version is looked up as though nothing were set: a mistyped
version says "I want a particular release", not "stay off the network",
and the latest is closer to that than failing the render would be.

## Usage

``` r
maidr_cdn_version_pin()
```

## Value

A semantic version, `"latest"`, or `NULL` when nothing usable is set
