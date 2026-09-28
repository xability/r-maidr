# Where maidr.js should fetch its locale packs from

Reads the `maidr.locale_base_url` option, then the
`MAIDR_LOCALE_BASE_URL` environment variable (see
[maidr-options](https://r.maidr.ai/reference/maidr-options.md)). A place
either of them names is declared in every document. `""` or `FALSE`
declares nothing. Left unset, a document that loads the bundled maidr.js
gets the packs of the bundled version on jsDelivr, and one that loads
maidr.js from the CDN gets nothing, since its packs sit beside that
copy.

## Usage

``` r
maidr_locale_base_url(use_cdn = FALSE)
```

## Arguments

- use_cdn:

  Whether the document loads maidr.js from the CDN

## Value

A directory URL, or `NULL` when nothing is to be declared
