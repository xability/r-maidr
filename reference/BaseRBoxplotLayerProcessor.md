# Base R Boxplot Layer Processor

Processes Base R boxplot layers by extracting statistical summaries and
generating selectors for boxplot components.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRBoxplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBoxplotLayerProcessor$process()`](#method-BaseRBoxplotLayerProcessor-process)

- [`BaseRBoxplotLayerProcessor$extract_data()`](#method-BaseRBoxplotLayerProcessor-extract_data)

- [`BaseRBoxplotLayerProcessor$generate_selectors()`](#method-BaseRBoxplotLayerProcessor-generate_selectors)

- [`BaseRBoxplotLayerProcessor$extract_axis_titles()`](#method-BaseRBoxplotLayerProcessor-extract_axis_titles)

- [`BaseRBoxplotLayerProcessor$extract_main_title()`](#method-BaseRBoxplotLayerProcessor-extract_main_title)

- [`BaseRBoxplotLayerProcessor$determine_orientation()`](#method-BaseRBoxplotLayerProcessor-determine_orientation)

- [`BaseRBoxplotLayerProcessor$clone()`](#method-BaseRBoxplotLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    BaseRBoxplotLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      layer_info = NULL
    )

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRBoxplotLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `determine_orientation()`

#### Usage

    BaseRBoxplotLayerProcessor$determine_orientation(layer_info)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBoxplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
