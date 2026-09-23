# Get the MAIDR CDN base URL

The jsDelivr directory holding the maidr.js that CDN documents load. The
version in it comes from
[`maidr_cdn_version()`](https://r.maidr.ai/reference/maidr_cdn_version.md):
the latest published maidr.js, resolved once per session, unless a
setting pins it.

## Usage

``` r
maidr_cdn_url()
```

## Value

CDN URL string, without a trailing slash

## Details

No `integrity` (SRI) attribute goes with it. A hash can only be written
for bytes known in advance, which here means the bundled version; the
CDN paths now load whatever version is current, whose hash this package
cannot know. The bundled copy needs none: it is shipped with the
package, not fetched from a third party.
