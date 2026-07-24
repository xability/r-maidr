# Candlestick Layer Processor

Candlestick Layer Processor

Candlestick Layer Processor

## Details

Processes candlestick chart layers produced by
\`tidyquant::geom_candlestick()\`.

tidyquant's \`geom_candlestick()\` expands into TWO ggplot layers: 1. A
\`GeomLinerangeBC\` (BC = barchart) layer drawing the high-low wicks. 2.
A \`GeomRectCS\` (CS = candlestick) layer drawing the open-close bodies.

The adapter tags the wick layer as \`"skip"\` so the orchestrator does
not create a separate maidr layer for it. This processor handles only
the second (body) layer, but reads back into the wick layer's grobs to
produce wick CSS selectors.

Output type: \`"candlestick"\`. Each data point is a
\`CandlestickPoint\` with \`value\`, \`open\`, \`high\`, \`low\`,
\`close\`, optional \`volume\`, computed \`trend\` (Bull / Bear /
Neutral) and \`volatility\` (high - low).

Selectors are emitted as a single \`CandlestickSelector\` object whose
\`body\` and \`wick\` fields are arrays of per-candle CSS selectors
using \`:nth-of-type\` against the rect/line elements of the
gridSVG-exported tidyquant grobs.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2CandlestickProcessor`

## Methods

### Public methods

- [`Ggplot2CandlestickProcessor$process()`](#method-Ggplot2CandlestickProcessor-process)

- [`Ggplot2CandlestickProcessor$extract_data()`](#method-Ggplot2CandlestickProcessor-extract_data)

- [`Ggplot2CandlestickProcessor$generate_selectors()`](#method-Ggplot2CandlestickProcessor-generate_selectors)

- [`Ggplot2CandlestickProcessor$extract_layer_axes()`](#method-Ggplot2CandlestickProcessor-extract_layer_axes)

- [`Ggplot2CandlestickProcessor$resolve_col()`](#method-Ggplot2CandlestickProcessor-resolve_col)

- [`Ggplot2CandlestickProcessor$format_x_value()`](#method-Ggplot2CandlestickProcessor-format_x_value)

- [`Ggplot2CandlestickProcessor$get_effective_mapping()`](#method-Ggplot2CandlestickProcessor-get_effective_mapping)

- [`Ggplot2CandlestickProcessor$get_original_data()`](#method-Ggplot2CandlestickProcessor-get_original_data)

- [`Ggplot2CandlestickProcessor$count_candles()`](#method-Ggplot2CandlestickProcessor-count_candles)

- [`Ggplot2CandlestickProcessor$find_panel_grob()`](#method-Ggplot2CandlestickProcessor-find_panel_grob)

- [`Ggplot2CandlestickProcessor$find_first_child_name()`](#method-Ggplot2CandlestickProcessor-find_first_child_name)

- [`Ggplot2CandlestickProcessor$clone()`](#method-Ggplot2CandlestickProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

Process the candlestick layer

#### Usage

    Ggplot2CandlestickProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data

- `gt`:

  Gtable object

- `scale_mapping`:

  Scale mapping (unused for candlestick)

- `grob_id`:

  Grob ID (faceting; not yet supported for candlestick)

- `panel_id`:

  Panel id (patchwork; accepted for signature parity)

- `panel_ctx`:

  Panel context (faceting; not yet supported)

#### Returns

Maidr candlestick layer list

------------------------------------------------------------------------

### Method `extract_data()`

Extract OHLC data points from the plot

#### Usage

    Ggplot2CandlestickProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL
    )

#### Arguments

- `plot`:

  ggplot2 object

- `built`:

  Built plot data

- `scale_mapping`:

  Unused

#### Returns

List of CandlestickPoint dicts

------------------------------------------------------------------------

### Method `generate_selectors()`

Generate candlestick CSS selectors

Returns a single \`CandlestickSelector\` object with \`body\` and
\`wick\` as single CSS group selectors (one per element kind, not per
candle). The maidr JS layer uses these to grab all candle elements at
once and then auto-derives \`open\`/\`close\` from body rect edges based
on trend.

#### Usage

    Ggplot2CandlestickProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  ggplot2 object

- `gt`:

  Gtable object

- `grob_id`:

  Grob ID (faceting)

- `panel_ctx`:

  Panel context (faceting)

#### Returns

Named list with \`body\` and (optionally) \`wick\` single-string
selectors, or empty list if grobs cannot be located.

------------------------------------------------------------------------

### Method `extract_layer_axes()`

Extract axes labels for candlestick layer

Candlestick layer mappings are typically NULL (top-level mapping carries
x/open/high/low/close). The base implementation only inspects
\`layer_mapping\$x\` and \`layer_mapping\$y\`, which yields blank
labels. Here we additionally fall back to \`plot\$mapping\$x\` and
synthesize a "Price" y-label since OHLC has no single y mapping.

#### Usage

    Ggplot2CandlestickProcessor$extract_layer_axes(plot, layout)

#### Arguments

- `plot`:

  ggplot2 object

- `layout`:

  Layout information

#### Returns

list(x = list(label = ...), y = list(label = ...))

------------------------------------------------------------------------

### Method `resolve_col()`

Resolve a mapping quosure to a column name in \`data\`

#### Usage

    Ggplot2CandlestickProcessor$resolve_col(mapping_expr, data)

------------------------------------------------------------------------

### Method `format_x_value()`

Format an x-axis value as character

#### Usage

    Ggplot2CandlestickProcessor$format_x_value(x)

------------------------------------------------------------------------

### Method `get_effective_mapping()`

Get the effective mapping (layer mapping merged on top)

#### Usage

    Ggplot2CandlestickProcessor$get_effective_mapping(plot)

------------------------------------------------------------------------

### Method `get_original_data()`

Get original data for the layer (falls back to plot\$data)

#### Usage

    Ggplot2CandlestickProcessor$get_original_data(plot)

------------------------------------------------------------------------

### Method `count_candles()`

Count candles from the original data

#### Usage

    Ggplot2CandlestickProcessor$count_candles(plot)

------------------------------------------------------------------------

### Method [`find_panel_grob()`](https://r.maidr.ai/reference/find_panel_grob.md)

Find the panel grob (panel_ctx-aware)

#### Usage

    Ggplot2CandlestickProcessor$find_panel_grob(gt, panel_ctx = NULL)

------------------------------------------------------------------------

### Method `find_first_child_name()`

Find the first descendant whose name matches \`pattern\`

#### Usage

    Ggplot2CandlestickProcessor$find_first_child_name(grob, pattern)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2CandlestickProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
