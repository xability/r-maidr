# MAIDR Package Options

Configure MAIDR interception and display behavior using R's options
system.

## Available Options

- `maidr.auto_show`:

  Logical. Master switch for all MAIDR interception. When FALSE, all
  plotting functions behave as standard R. Default: TRUE.

- `maidr.base_r`:

  Logical. Enable Base R plot interception. When TRUE, Base R plots are
  captured and displayed in the MAIDR viewer. Default: TRUE.

- `maidr.ggplot2`:

  Logical. Enable ggplot2 auto-display. When TRUE, ggplot2 objects are
  automatically rendered in the MAIDR viewer instead of the standard
  graphics device. Default: TRUE.

- `maidr.startup_message`:

  Logical. Show startup message when package is loaded. Default: TRUE.

- `maidr.dotpad_sdk_url`:

  Character. URL of a copy of the DotPad tactile-display SDK module
  (`DotPadSDK-3.0.3.js`) that you serve yourself. maidr.js does not
  bundle the SDK, whose braille engine is a 14 MB liblouis build; unless
  told otherwise it imports the vendor's copy from jsDelivr the first
  time a DotPad is connected, from a document rendered with
  `use_cdn = FALSE` as much as any other. Set this to keep that path off
  the network too. Falls back to the environment variable
  `MAIDR_DOTPAD_SDK_URL`. Default: unset.

- `maidr.dotpad_asset_base_url`:

  Character. URL of the directory holding the SDK's braille engine
  (`liblouis.js`, `.wasm`, `.data`), needed only when it is not the
  `lib/` folder beside the module. Falls back to the environment
  variable `MAIDR_DOTPAD_ASSET_BASE_URL`. Default: unset.

- `maidr.dotpad_sdk_dir`:

  Character. Directory where
  [`maidr_download_dotpad_sdk()`](https://r.maidr.ai/reference/maidr_download_dotpad_sdk.md)
  writes the SDK and where
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) look for it
  when a document is rendered with `use_cdn = FALSE`. Falls back to the
  environment variable `MAIDR_DOTPAD_SDK_DIR`, then to a per-user cache
  directory. Default: unset.

- `maidr.cdn_version`:

  Character. Which MAIDR.js the CDN paths load: a version such as
  `"4.9.0"` (a leading `v` is accepted), `"bundled"` for the version
  bundled with this package (`maidr:::MAIDR_VERSION`), or `"latest"` for
  jsDelivr's `@latest` tag. Either tag skips the version lookup
  described below. Anything else warns once and is ignored. Falls back
  to the environment variable `MAIDR_CDN_VERSION`. Default: unset, which
  loads the latest published version.

- `maidr.cdn_timeout`:

  Numeric. Seconds allowed for the whole CDN version lookup, clamped to
  between 0.1 and 30. Falls back to the environment variable
  `MAIDR_CDN_TIMEOUT`. Default: 3.

## Setting Options

Options can be set in your `.Rprofile` to persist across sessions:


    # Disable ggplot2 interception by default
    options(maidr.ggplot2 = FALSE)

    # Disable all interception
    options(maidr.auto_show = FALSE)

    # Suppress startup message
    options(maidr.startup_message = FALSE)

    # Serve the DotPad SDK from your own server instead of jsDelivr
    options(
      maidr.dotpad_sdk_url = "https://example.org/vendor/DotPadSDK-3.0.3.js",
      maidr.dotpad_asset_base_url = "https://example.org/vendor/lib/"
    )

## DotPad SDK and offline documents

The two `maidr.dotpad_*_url` options are written into every document
this package produces ([`show()`](https://r.maidr.ai/reference/show.md),
[`save_html()`](https://r.maidr.ai/reference/save_html.md), the
htmlwidget, knitr and Shiny) as the globals
`window.MAIDR_DOTPAD_SDK_URL` and `window.MAIDR_DOTPAD_ASSET_BASE_URL`,
ahead of `maidr.js`, which reads them when a DotPad is connected.
Nothing is written when neither is set. Without them a DotPad needs
network access to jsDelivr on first connect, even from a
`use_cdn = FALSE` document; the rest of the document works offline
either way.

The other way to keep a DotPad off the network is to download the SDK
once with
[`maidr_download_dotpad_sdk()`](https://r.maidr.ai/reference/maidr_download_dotpad_sdk.md):
[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) then copy it
into `lib/dotpad-sdk-<version>/` beside every `use_cdn = FALSE` document
and declare the globals with that relative path. A configured URL wins
over a downloaded copy. The widget, knitr and Shiny paths render their
charts in `srcdoc` frames, where a relative path has nothing to resolve
against, so they use only the URL options.

## Which MAIDR.js the CDN serves

Documents that load MAIDR.js from the jsDelivr CDN –
[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) with
`use_cdn = TRUE`, and the widget, knitr and Shiny paths when they find
the machine online – load the latest published MAIDR.js, as the Python
binding does. Documents rendered with `use_cdn = FALSE` load the copy
bundled with this package and make no network request.

The first CDN document in an R session asks which version is the latest:
jsDelivr's data API
(<https://data.jsdelivr.com/v1/packages/npm/maidr/resolved?specifier=latest>),
then the npm registry
(<https://registry.npmjs.org/-/package/maidr/dist-tags>) if that fails,
within `maidr.cdn_timeout` seconds for the two together. The answer is
kept for the rest of the session, and the document names that version,
which never changes under the reader. When neither answers – offline,
blocked, timed out – that too is kept, no error is raised, and the
document names the version bundled with this package, the copy
`use_cdn = FALSE` would serve, as the Python binding does. So does an
answer older than the bundled version. The mutable `maidr@latest` tag,
which jsDelivr caches for up to a week, is used only when
`maidr.cdn_version = "latest"` asks for it.

Pin a version when a document has to load the same MAIDR.js wherever and
whenever it is opened, or to keep the one this package was tested with:


    # The version bundled with this package, no lookup
    options(maidr.cdn_version = "bundled")

    # A particular release
    options(maidr.cdn_version = "4.9.0")

    # Or from the shell, for every session
    # MAIDR_CDN_VERSION=bundled Rscript render.R
