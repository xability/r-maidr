# Download the DotPad SDK for use offline

maidr.js drives a [DotPad tactile
display](https://maidr.ai/docs/TACTILE_DISPLAY.html) through the
vendor's SDK, which it does not bundle: the braille engine inside it is
a 14 MB liblouis build, and every document would carry it for the few
readers who own the device. By default maidr.js imports the vendor's
published copy from jsDelivr, pinned to a commit, the first time a
DotPad is connected – the one path an offline document
(`use_cdn = FALSE`) still takes to the network.

## Usage

``` r
maidr_download_dotpad_sdk(
  dir = maidr_dotpad_sdk_dir(),
  force = FALSE,
  quiet = FALSE
)
```

## Arguments

- dir:

  Where to write. Defaults to the option `maidr.dotpad_sdk_dir`, the
  environment variable `MAIDR_DOTPAD_SDK_DIR`, or a per-user cache
  directory.

- force:

  Refetch files that are already present and correct.

- quiet:

  Say nothing about what was fetched.

## Value

The directory, invisibly.

## Details

This fetches that pinned copy once – the module, the liblouis build, and
the LGPL licence text and wrapper sources the vendor asks redistributors
to keep beside it – verifying every file against its recorded size and
digests (MD5, and SHA-256 on R 4.5 or later), and writes a
`manifest.json` beside them naming the commit they came from. From then
on [`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) copy it into
`lib/dotpad-sdk-<version>/` next to every `use_cdn = FALSE` document and
tell maidr.js where it is, so a reader connects a DotPad without the
network. A file already present and correct is left alone, so a second
call costs nothing.

A page served from somewhere else – an intranet host, or a knitr
document, whose charts live in `srcdoc` frames with no base URL for a
relative path to resolve against – names its copy by URL instead,
through the options `maidr.dotpad_sdk_url` and
`maidr.dotpad_asset_base_url`; see
[maidr-options](https://r.maidr.ai/reference/maidr-options.md). A
configured URL wins over a downloaded copy.

## See also

[maidr-options](https://r.maidr.ai/reference/maidr-options.md) for
naming a copy by URL

## Examples

``` r
if (FALSE) { # \dontrun{
maidr_download_dotpad_sdk() # about 14 MB, once
save_html(p, "chart.html", use_cdn = FALSE) # carries the SDK in lib/
} # }
```
