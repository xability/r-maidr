# Base R Candlestick Layer Processor

Base R Candlestick Layer Processor

Base R Candlestick Layer Processor

## Details

Processes Base R candlestick chart layers produced by
\`quantmod::chartSeries(x, type = "candlesticks")\`.

Each xts row becomes a single navigable \`CandlestickPoint\` with
\`value\`, \`open\`, \`high\`, \`low\`, \`close\`, computed \`trend\`
(Bull / Bear / Neutral), \`volatility\` (high - low) and optional
\`volume\` (when \`quantmod::has.Vo()\` is \`TRUE\`).

Selectors are derived from the gridSVG export of the chartSeries grob
(captured via \`ggplotify::as.grob()\`). chartSeries draws candle bodies
via a single vectorized \`rect()\` call (each candle body is one SVG
\`\<rect\>\` child of \`graphics-plot-\<N\>-rect-\*\`) and upper/lower
wicks via \`segments()\` calls (one SVG \`\<polyline\>\` per wick under
\`graphics-plot-\<N\>-segments-\*\`).

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRCandlestickLayerProcessor`

## Methods

### Public methods

- [`BaseRCandlestickLayerProcessor$process()`](#method-BaseRCandlestickLayerProcessor-process)

- [`BaseRCandlestickLayerProcessor$has_add_vo()`](#method-BaseRCandlestickLayerProcessor-has_add_vo)

- [`BaseRCandlestickLayerProcessor$build_volume_layer()`](#method-BaseRCandlestickLayerProcessor-build_volume_layer)

- [`BaseRCandlestickLayerProcessor$generate_volume_selectors()`](#method-BaseRCandlestickLayerProcessor-generate_volume_selectors)

- [`BaseRCandlestickLayerProcessor$extract_data()`](#method-BaseRCandlestickLayerProcessor-extract_data)

- [`BaseRCandlestickLayerProcessor$generate_selectors()`](#method-BaseRCandlestickLayerProcessor-generate_selectors)

- [`BaseRCandlestickLayerProcessor$extract_axis_titles()`](#method-BaseRCandlestickLayerProcessor-extract_axis_titles)

- [`BaseRCandlestickLayerProcessor$extract_main_title()`](#method-BaseRCandlestickLayerProcessor-extract_main_title)

- [`BaseRCandlestickLayerProcessor$format_x_values()`](#method-BaseRCandlestickLayerProcessor-format_x_values)

- [`BaseRCandlestickLayerProcessor$collect_grob_names()`](#method-BaseRCandlestickLayerProcessor-collect_grob_names)

- [`BaseRCandlestickLayerProcessor$sort_ids()`](#method-BaseRCandlestickLayerProcessor-sort_ids)

- [`BaseRCandlestickLayerProcessor$find_grob_by_name()`](#method-BaseRCandlestickLayerProcessor-find_grob_by_name)

- [`BaseRCandlestickLayerProcessor$grob_coord_count()`](#method-BaseRCandlestickLayerProcessor-grob_coord_count)

- [`BaseRCandlestickLayerProcessor$pick_largest_child_group()`](#method-BaseRCandlestickLayerProcessor-pick_largest_child_group)

- [`BaseRCandlestickLayerProcessor$clone()`](#method-BaseRCandlestickLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    BaseRCandlestickLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      layer_info = NULL
    )

------------------------------------------------------------------------

### Method `has_add_vo()`

Detect whether the chartSeries call requests addVo()

#### Usage

    BaseRCandlestickLayerProcessor$has_add_vo(layer_info)

------------------------------------------------------------------------

### Method `build_volume_layer()`

Build a "bar" layer carrying volume data

#### Usage

    BaseRCandlestickLayerProcessor$build_volume_layer(layer_info, gt, candle_data)

------------------------------------------------------------------------

### Method `generate_volume_selectors()`

Generate selectors for the addVo() volume bar panel

chartSeries(TA = "addVo()") creates a second plotting window. In the
gridSVG export that maps to a second \`graphics-plot-\<N\>\` group
(typically N = 2). Returns a per-bar selector list so each volume bar
can be individually highlighted on navigation; matches the bar layer
contract used by the Base R barplot processor.

#### Usage

    BaseRCandlestickLayerProcessor$generate_volume_selectors(
      layer_info,
      gt,
      n_bars
    )

------------------------------------------------------------------------

### Method `extract_data()`

Extract OHLC data points from the chartSeries call

#### Usage

    BaseRCandlestickLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer info containing the recorded plot call

#### Returns

List of CandlestickPoint dicts

------------------------------------------------------------------------

### Method `generate_selectors()`

Generate CSS selectors for the candlestick layer

Returns ONE \`CandlestickSelector\` object (matching the maidr JS
frontend contract in \`src/model/candlestick.ts::mapToSvgElements\`).
The returned object has these named character-vector keys: - \`body\`
length-N vector, one per-candle body-rect selector - \`wickHigh\`
length-N vector, one per-candle upper-wick selector (omitted if only one
segments group is present) - \`wickLow\` length-N vector, one per-candle
lower-wick selector (omitted if only one segments group is present) -
\`wick\` length-N vector, used as fallback when there is only one
segments group (the frontend falls back to \`wick\` when \`wickHigh\` /
\`wickLow\` are absent).

gridSVG emits a child id \`\<group-id\>.1.\<i\>\` for each primitive in
a vectorized draw call. The frontend iterates each string array
(\`collectElements(arr)\`) and picks the i-th element via
\`getElementAt(\*, i)\`, so per-candle selectors are required for
single-candle highlighting on arrow-key navigation.

IMPORTANT: do NOT return an array of objects (e.g. \`\[\[body, wick\],
...\]\`). The frontend's \`Array.isArray()\` branch would then take
\`selectors\[0\]\` (the first dict) and pass it to \`querySelectorAll\`,
yielding a JS \`SyntaxError: '\[object Object\]' is not a valid
selector\`. The boxplot pattern of per-item dicts does NOT apply here
because each chart model has its own contract.

#### Usage

    BaseRCandlestickLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `layer_info`:

  Layer info (used for fallback plot index)

- `gt`:

  The captured chartSeries grob (from ggplotify::as.grob)

- `extracted_data`:

  Previously extracted data (used for count)

#### Returns

Named list (single CandlestickSelector) or \`list()\` when grobs cannot
be located.

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRCandlestickLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRCandlestickLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `format_x_values()`

Format a vector of x-axis index values to character

#### Usage

    BaseRCandlestickLayerProcessor$format_x_values(idx)

------------------------------------------------------------------------

### Method `collect_grob_names()`

Recursively collect all grob names in a grob tree

#### Usage

    BaseRCandlestickLayerProcessor$collect_grob_names(g)

------------------------------------------------------------------------

### Method `sort_ids()`

Sort grob ids by trailing integer suffix

#### Usage

    BaseRCandlestickLayerProcessor$sort_ids(ids)

------------------------------------------------------------------------

### Method `find_grob_by_name()`

Find the grob node whose name matches \`id\`

#### Usage

    BaseRCandlestickLayerProcessor$find_grob_by_name(g, id)

------------------------------------------------------------------------

### Method `grob_coord_count()`

Count the number of primitive coordinates a grob carries

#### Usage

    BaseRCandlestickLayerProcessor$grob_coord_count(g)

------------------------------------------------------------------------

### Method `pick_largest_child_group()`

Pick the rect-id whose grob has the most coordinates

#### Usage

    BaseRCandlestickLayerProcessor$pick_largest_child_group(gt, ids)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRCandlestickLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
