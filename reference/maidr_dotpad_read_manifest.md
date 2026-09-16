# Parse the shipped DotPad SDK manifest

Split from
[`maidr_dotpad_sdk_manifest()`](https://r.maidr.ai/reference/maidr_dotpad_sdk_manifest.md)
so the read happens once and the parsing is testable on its own. Every
field is checked, because the file is not authored here:
`fetch-maidr-bundle.sh` copies whatever `dist/dotpad-sdk.json` the
pinned `maidr.js` release ships. A field that changed shape upstream is
named as a bad manifest rather than surfacing later as a `vapply` type
error.

## Usage

``` r
maidr_dotpad_read_manifest(path = NULL)
```

## Arguments

- path:

  Where to read from. Defaults to the installed `inst/` copy.

## Value

The manifest, in the shape
[`maidr_dotpad_sdk_manifest()`](https://r.maidr.ai/reference/maidr_dotpad_sdk_manifest.md)
returns.
