# Base R Dodged Bar Layer Processor

Processes Base R dodged bar plot layers with proper ordering to match
backend logic

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRDodgedBarLayerProcessor`

## Methods

### Public methods

- [`BaseRDodgedBarLayerProcessor$process()`](#method-BaseRDodgedBarLayerProcessor-process)

- [`BaseRDodgedBarLayerProcessor$extract_data()`](#method-BaseRDodgedBarLayerProcessor-extract_data)

- [`BaseRDodgedBarLayerProcessor$generate_selectors()`](#method-BaseRDodgedBarLayerProcessor-generate_selectors)

- [`BaseRDodgedBarLayerProcessor$find_rect_grobs()`](#method-BaseRDodgedBarLayerProcessor-find_rect_grobs)

- [`BaseRDodgedBarLayerProcessor$generate_selectors_from_grob()`](#method-BaseRDodgedBarLayerProcessor-generate_selectors_from_grob)

- [`BaseRDodgedBarLayerProcessor$extract_axis_titles()`](#method-BaseRDodgedBarLayerProcessor-extract_axis_titles)

- [`BaseRDodgedBarLayerProcessor$extract_main_title()`](#method-BaseRDodgedBarLayerProcessor-extract_main_title)

- [`BaseRDodgedBarLayerProcessor$clone()`](#method-BaseRDodgedBarLayerProcessor-clone)

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

    BaseRDodgedBarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      layer_info = NULL
    )

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRDodgedBarLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRDodgedBarLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_rect_grobs()`

#### Usage

    BaseRDodgedBarLayerProcessor$find_rect_grobs(grob, call_index)

------------------------------------------------------------------------

### Method `generate_selectors_from_grob()`

#### Usage

    BaseRDodgedBarLayerProcessor$generate_selectors_from_grob(grob, call_index)

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRDodgedBarLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRDodgedBarLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRDodgedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
