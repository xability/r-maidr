# Base R Point/Scatter Plot Layer Processor

Processes Base R scatter plot layers based on recorded plot calls

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRPointLayerProcessor`

## Methods

### Public methods

- [`BaseRPointLayerProcessor$process()`](#method-BaseRPointLayerProcessor-process)

- [`BaseRPointLayerProcessor$needs_reordering()`](#method-BaseRPointLayerProcessor-needs_reordering)

- [`BaseRPointLayerProcessor$extract_data()`](#method-BaseRPointLayerProcessor-extract_data)

- [`BaseRPointLayerProcessor$extract_axis_titles()`](#method-BaseRPointLayerProcessor-extract_axis_titles)

- [`BaseRPointLayerProcessor$extract_main_title()`](#method-BaseRPointLayerProcessor-extract_main_title)

- [`BaseRPointLayerProcessor$generate_selectors()`](#method-BaseRPointLayerProcessor-generate_selectors)

- [`BaseRPointLayerProcessor$clone()`](#method-BaseRPointLayerProcessor-clone)

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

    BaseRPointLayerProcessor$process(
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

    BaseRPointLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRPointLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRPointLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRPointLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRPointLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPointLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
