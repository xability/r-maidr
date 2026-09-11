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
  (`DotPadSDK-3.0.2.js`) that you serve yourself. maidr.js does not
  bundle the SDK, whose licence does not permit redistribution; unless
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
      maidr.dotpad_sdk_url = "https://example.org/vendor/DotPadSDK-3.0.2.js",
      maidr.dotpad_asset_base_url = "https://example.org/vendor/lib/"
    )

## DotPad SDK and offline documents

The two `maidr.dotpad_*` options are written into every document this
package produces ([`show()`](https://r.maidr.ai/reference/show.md),
[`save_html()`](https://r.maidr.ai/reference/save_html.md), the
htmlwidget, knitr and Shiny) as the globals
`window.MAIDR_DOTPAD_SDK_URL` and `window.MAIDR_DOTPAD_ASSET_BASE_URL`,
ahead of `maidr.js`, which reads them when a DotPad is connected.
Nothing is written when neither is set. Without them a DotPad needs
network access to jsDelivr on first connect, even from a
`use_cdn = FALSE` document; the rest of the document works offline
either way.
