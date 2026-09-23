# The maidr.js version CDN documents load

In order: the `maidr.cdn_version` option, the `MAIDR_CDN_VERSION`
environment variable, then the latest published version, looked up once
per session by
[`maidr_resolve_cdn_version()`](https://r.maidr.ai/reference/maidr_resolve_cdn_version.md).

## Usage

``` r
maidr_cdn_version()
```

## Value

A single string: a semantic version, or `"latest"` when that tag was
pinned

## Details

When the lookup fails – offline, blocked, timed out, or an answer that
is not a version – this returns the bundled version, `MAIDR_VERSION`, as
py-maidr does (xability/py-maidr#295). The alternative, jsDelivr's
`@latest` tag, is a mutable alias that jsDelivr serves with a cache
lifetime of up to seven days, so degrading to it would let a browser
replay a week-old build in exactly the case the lookup exists to cover.
The bundled version is a real published release, its URL is immutable,
and it is the copy `use_cdn = FALSE` would have served anyway. What it
costs is that a network hiccup leaves the session on a possibly older
release. `@latest` is still emitted when it is asked for by name, with
`options(maidr.cdn_version = "latest")`.

A resolver answer older than the bundled version is refused the same way
(see
[`maidr_is_older_than_bundled()`](https://r.maidr.ai/reference/maidr_is_older_than_bundled.md)):
nothing obliges a resolver, or whatever sits between it and this
session, to answer with the current release, and the bundled version is
the one known to have shipped with this package.
