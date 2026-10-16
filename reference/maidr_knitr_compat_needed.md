# Whether a knitted page may load a maidr.js older than 4.15.0

A page loads one maidr.js: that of the first dependency named `maidr`
the document declares. htmltools keeps the newest of the dependencies of
one name, the first of them when they tie, and every `maidr` dependency
carries the bundled version, the CDN one of
`maidr_htmlwidget(use_cdn = TRUE)` included, whatever release its URL
names. So a widget that loads from the CDN, in a chunk before the first
inline chart, puts the release its URL names on the page in place of the
bundle, and `maidr.cdn_version` can pin that to an older one.

## Usage

``` r
maidr_knitr_compat_needed(meta = knitr::knit_meta(clean = FALSE))
```

## Arguments

- meta:

  The knit's metadata so far.

## Value

`TRUE` when the page needs
[`maidr_knitr_compat_dependency()`](https://r.maidr.ai/reference/maidr_knitr_compat_dependency.md)

## Details

The first `maidr` dependency of the knit so far decides, read when a
chart declares the page's dependencies: the bundled `MAIDR_VERSION` when
it names no URL – an inline chart's, or a widget's that does not load
from the CDN – or the release its URL names. One older than
[MAIDR_PAGE_GUARDS_VERSION](https://r.maidr.ai/reference/MAIDR_PAGE_GUARDS_VERSION.md),
or `latest`, which jsDelivr may answer with a release it cached a week
ago, needs the copies of
[`maidr_knitr_compat_dependency()`](https://r.maidr.ai/reference/maidr_knitr_compat_dependency.md).
