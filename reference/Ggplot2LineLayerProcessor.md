# Final Line Layer Processor - Uses Actual SVG Structure

Processes line plot layers using the actual gridSVG structure
discovered: - Lines: GRID.polyline.61.1.1, GRID.polyline.61.1.2,
GRID.polyline.61.1.3 - Points: geom_point.points.63.1.1 through
geom_point.points.63.1.24 (grouped by series)

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
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

- [`Ggplot2LineLayerProcessor$extract_data()`](#method-Ggplot2LineLayerProcessor-extract_data)

- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](#method-Ggplot2LineLayerProcessor-extract_multiline_data)

- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](#method-Ggplot2LineLayerProcessor-extract_single_line_data)

- [`Ggplot2LineLayerProcessor$get_group_column()`](#method-Ggplot2LineLayerProcessor-get_group_column)

- [`Ggplot2LineLayerProcessor$generate_selectors()`](#method-Ggplot2LineLayerProcessor-generate_selectors)

- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](#method-Ggplot2LineLayerProcessor-generate_multiline_selectors)

- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](#method-Ggplot2LineLayerProcessor-generate_single_line_selector)

- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](#method-Ggplot2LineLayerProcessor-find_main_polyline_grob)

- [`Ggplot2LineLayerProcessor$needs_reordering()`](#method-Ggplot2LineLayerProcessor-needs_reordering)

- [`Ggplot2LineLayerProcessor$clone()`](#method-Ggplot2LineLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$reorder_layer_data()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-set_last_result)

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

List with data and selectors Extract data from line layer (single or
multiline)

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

List of arrays, each containing series data points Extract data for
multiple line series

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

    Ggplot2LineLayerProcessor$extract_single_line_data(layer_data)

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

List with single selector Find the main polyline grob (GRID.polyline.XX)

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
