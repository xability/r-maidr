# Base R Stacked Bar Layer Processor

Processes Base R stacked bar plot layers intercepted via the patching
system. Assumes sorting by x (columns) and then fill (rows) has already
been applied by the \`SortingPatcher\`.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRStackedBarLayerProcessor`

## Methods

### Public methods

- [`BaseRStackedBarLayerProcessor$process()`](#method-BaseRStackedBarLayerProcessor-process)

- [`BaseRStackedBarLayerProcessor$needs_reordering()`](#method-BaseRStackedBarLayerProcessor-needs_reordering)

- [`BaseRStackedBarLayerProcessor$extract_data()`](#method-BaseRStackedBarLayerProcessor-extract_data)

- [`BaseRStackedBarLayerProcessor$extract_axis_titles()`](#method-BaseRStackedBarLayerProcessor-extract_axis_titles)

- [`BaseRStackedBarLayerProcessor$extract_main_title()`](#method-BaseRStackedBarLayerProcessor-extract_main_title)

- [`BaseRStackedBarLayerProcessor$generate_selectors()`](#method-BaseRStackedBarLayerProcessor-generate_selectors)

- [`BaseRStackedBarLayerProcessor$find_rect_groups()`](#method-BaseRStackedBarLayerProcessor-find_rect_groups)

- [`BaseRStackedBarLayerProcessor$clone()`](#method-BaseRStackedBarLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    BaseRStackedBarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
    )

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    BaseRStackedBarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRStackedBarLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRStackedBarLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRStackedBarLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRStackedBarLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_rect_groups()`

#### Usage

    BaseRStackedBarLayerProcessor$find_rect_groups(grob, call_index)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStackedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
