# Final Line Layer Processor - Uses Actual SVG Structure

Final Line Layer Processor - Uses Actual SVG Structure

Final Line Layer Processor - Uses Actual SVG Structure

## Details

Processes line plot layers using the actual gridSVG structure
discovered: - Lines: GRID.polyline.61.1.1, GRID.polyline.61.1.2,
GRID.polyline.61.1.3 - Points: geom_point.points.63.1.1 through
geom_point.points.63.1.24 (grouped by series)

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2LineLayerProcessor`

## Public fields

- `layer_info`:

  Information about the layer being processed

- `last_result`:

  The last processing result

## Active bindings

- `layer_info`:

  Information about the layer being processed

- `last_result`:

  The last processing result

## Methods

### Public methods

- [`Ggplot2LineLayerProcessor$process()`](#method-Ggplot2LineLayerProcessor-process)

- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](#method-Ggplot2LineLayerProcessor-extract_layer_axes)

- [`Ggplot2LineLayerProcessor$extract_data()`](#method-Ggplot2LineLayerProcessor-extract_data)

- [`Ggplot2LineLayerProcessor$format_x_value()`](#method-Ggplot2LineLayerProcessor-format_x_value)

- [`Ggplot2LineLayerProcessor$get_original_x_column()`](#method-Ggplot2LineLayerProcessor-get_original_x_column)

- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](#method-Ggplot2LineLayerProcessor-extract_multiline_data)

- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](#method-Ggplot2LineLayerProcessor-extract_single_line_data)

- [`Ggplot2LineLayerProcessor$get_group_column()`](#method-Ggplot2LineLayerProcessor-get_group_column)

- [`Ggplot2LineLayerProcessor$generate_selectors()`](#method-Ggplot2LineLayerProcessor-generate_selectors)

- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](#method-Ggplot2LineLayerProcessor-generate_multiline_selectors)

- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](#method-Ggplot2LineLayerProcessor-generate_single_line_selector)

- [`Ggplot2LineLayerProcessor$find_all_polyline_grobs()`](#method-Ggplot2LineLayerProcessor-find_all_polyline_grobs)

- [`Ggplot2LineLayerProcessor$line_layer_position()`](#method-Ggplot2LineLayerProcessor-line_layer_position)

- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](#method-Ggplot2LineLayerProcessor-find_main_polyline_grob)

- [`Ggplot2LineLayerProcessor$needs_reordering()`](#method-Ggplot2LineLayerProcessor-needs_reordering)

- [`Ggplot2LineLayerProcessor$clone()`](#method-Ggplot2LineLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2LineLayerProcessor$process(
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

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List with data and selectors Extract axes labels for line layers, with a
special case for moving-average geoms (e.g. \`tidyquant::geom_ma\`).

By default the parent \`LayerProcessor\$extract_layer_axes()\` reads the
y-label from the layer's aesthetic mapping. For a moving-average overlay
typically written as \`geom_ma(aes(y = close), ma_fun = SMA, ...)\`,
this yields the literal input-column name \`"close"\`, which is
misleading: the value being plotted (and announced during navigation) is
the moving average of \`close\`, not \`close\` itself. We detect
\`GeomMA\` (the class of tidyquant's geom_ma layer) and override the
y-label accordingly. Plain \`geom_line\` / \`geom_smooth\` overlays are
untouched.

------------------------------------------------------------------------

### Method `extract_layer_axes()`

#### Usage

    Ggplot2LineLayerProcessor$extract_layer_axes(plot, layout)

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

#### Returns

list(x = list(label = ...), y = list(label = ...)) Extract data from
line layer (single or multiline)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2LineLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List of arrays, each containing series data points

------------------------------------------------------------------------

### Method `format_x_value()`

Format an x-axis value as character.

Date / POSIXct / POSIXlt values are formatted via \`format()\` so that a
\`Date\` column emits ISO date strings (e.g. "2024-01-02") rather than
the underlying numeric days-since-epoch representation produced by
\`ggplot_build()\`. All other types use \`as.character()\`. Mirrors
\`Ggplot2BarLayerProcessor\$format_x_value()\` so bar and line layers
from the same Date column align string-wise.

#### Usage

    Ggplot2LineLayerProcessor$format_x_value(x)

------------------------------------------------------------------------

### Method `get_original_x_column()`

Recover the original (untransformed) x column for a layer.

\`ggplot_build()\` transforms Date / POSIXct columns into numeric
days-since-epoch on \`built\$data\[\[i\]\]\$x\`. To emit ISO strings we
need the original column from \`plot\$data\` (or the layer's own
\`data\`).

Returns the per-row vector of x values aligned to \`built_data\` if a
simple column reference is found and the lengths match, otherwise NULL.
Extract data for multiple line series

#### Usage

    Ggplot2LineLayerProcessor$get_original_x_column(plot, built_data)

------------------------------------------------------------------------

### Method `extract_multiline_data()`

#### Usage

    Ggplot2LineLayerProcessor$extract_multiline_data(layer_data, plot)

#### Arguments

- `layer_data`:

  The built layer data

- `plot`:

  The original ggplot2 object

#### Returns

List of arrays, each containing series data Extract data for single line
(backward compatibility)

------------------------------------------------------------------------

### Method `extract_single_line_data()`

#### Usage

    Ggplot2LineLayerProcessor$extract_single_line_data(layer_data, plot = NULL)

#### Arguments

- `layer_data`:

  The built layer data

#### Returns

List containing single series data Get the grouping column name from
plot mappings

------------------------------------------------------------------------

### Method `get_group_column()`

#### Usage

    Ggplot2LineLayerProcessor$get_group_column(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Name of the grouping column Generate selectors using actual SVG
structure

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2LineLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

#### Returns

List of selectors for each series Generate selectors for multiline plots
using actual structure

------------------------------------------------------------------------

### Method `generate_multiline_selectors()`

#### Usage

    Ggplot2LineLayerProcessor$generate_multiline_selectors(base_id, num_series)

#### Arguments

- `base_id`:

  The base ID from the grob (e.g., "61")

- `num_series`:

  Number of series

#### Returns

List of selectors Generate selector for single line plot

------------------------------------------------------------------------

### Method `generate_single_line_selector()`

#### Usage

    Ggplot2LineLayerProcessor$generate_single_line_selector(base_id)

#### Arguments

- `base_id`:

  The base ID from the grob

#### Returns

List with single selector Find all polyline parent grobs
(GRID.polyline.XX) in the panel.

------------------------------------------------------------------------

### Method `find_all_polyline_grobs()`

#### Usage

    Ggplot2LineLayerProcessor$find_all_polyline_grobs(gt)

------------------------------------------------------------------------

### Method `line_layer_position()`

#### Usage

    Ggplot2LineLayerProcessor$line_layer_position(plot)

------------------------------------------------------------------------

### Method `find_main_polyline_grob()`

#### Usage

    Ggplot2LineLayerProcessor$find_main_polyline_grob(gt)

#### Arguments

- `gt`:

  The gtable to search

#### Returns

The main polyline grob or NULL Check if layer needs reordering

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    Ggplot2LineLayerProcessor$needs_reordering()

#### Returns

FALSE (line plots typically don't need reordering)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2LineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
