# Where maidr.js loads the DotPad SDK from

maidr.js does not bundle the DotPad tactile-display SDK: it ships
without a licence permitting redistribution, so the first time a reader
connects a DotPad, maidr.js imports the SDK from the vendor's published
copy on jsDelivr. That is the one path an offline document
(`use_cdn = FALSE`) still takes to the network. The document renders,
sonifies and brailles without it; only connecting a DotPad needs it,
unless the page names its own copy of the SDK.

## Usage

``` r
maidr_dotpad_config()
```

## Value

A list with `sdk_url` and `asset_base_url`, each a single string or
`NULL` when unset.

## Details

maidr.js reads two globals off the page before it loads:
`window.MAIDR_DOTPAD_SDK_URL`, the SDK ES module, and
`window.MAIDR_DOTPAD_ASSET_BASE_URL`, the directory holding the braille
engine's `liblouis.js`, `.wasm` and `.data` files (by default the `lib/`
folder beside the module). This reads the R-side settings for them: the
options `maidr.dotpad_sdk_url` and `maidr.dotpad_asset_base_url`,
falling back to the environment variables `MAIDR_DOTPAD_SDK_URL` and
`MAIDR_DOTPAD_ASSET_BASE_URL`, which carry the same names as the
globals. An empty value counts as unset.

## See also

[maidr-options](https://r.maidr.ai/reference/maidr-options.md)
