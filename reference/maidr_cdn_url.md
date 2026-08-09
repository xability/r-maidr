# Get the MAIDR CDN base URL

Pinned to the same version as the bundled assets: the maidr-data JSON
emitted by this package is written against that frontend version, so an
unpinned `@latest` CDN could silently break rendering when upstream
releases a breaking change.

## Usage

``` r
maidr_cdn_url()
```

## Value

CDN URL string
