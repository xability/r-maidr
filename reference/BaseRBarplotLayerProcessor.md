# Base R Bar Plot Layer Processor

Base R Bar Plot Layer Processor

Base R Bar Plot Layer Processor

## Details

Processes Base R bar plot layers based on recorded plot calls

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRBarplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBarplotLayerProcessor$process()`](#method-BaseRBarplotLayerProcessor-process)

- [`BaseRBarplotLayerProcessor$needs_reordering()`](#method-BaseRBarplotLayerProcessor-needs_reordering)

- [`BaseRBarplotLayerProcessor$extract_data()`](#method-BaseRBarplotLayerProcessor-extract_data)

- [`BaseRBarplotLayerProcessor$extract_axis_titles()`](#method-BaseRBarplotLayerProcessor-extract_axis_titles)

- [`BaseRBarplotLayerProcessor$extract_main_title()`](#method-BaseRBarplotLayerProcessor-extract_main_title)

- [`BaseRBarplotLayerProcessor$generate_selectors()`](#method-BaseRBarplotLayerProcessor-generate_selectors)

- [`BaseRBarplotLayerProcessor$find_rect_grobs()`](#method-BaseRBarplotLayerProcessor-find_rect_grobs)

- [`BaseRBarplotLayerProcessor$generate_selectors_from_grob()`](#method-BaseRBarplotLayerProcessor-generate_selectors_from_grob)

- [`BaseRBarplotLayerProcessor$clone()`](#method-BaseRBarplotLayerProcessor-clone)

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

    BaseRBarplotLayerProcessor$process(
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

    BaseRBarplotLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRBarplotLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRBarplotLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRBarplotLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRBarplotLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_rect_grobs()`

Recursively find rect grobs in the grob tree (like ggplot2 does)

#### Usage

    BaseRBarplotLayerProcessor$find_rect_grobs(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  The plot call index to match

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### Method `generate_selectors_from_grob()`

Generate selectors from grob tree (like ggplot2 does)

#### Usage

    BaseRBarplotLayerProcessor$generate_selectors_from_grob(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  The plot call index

#### Returns

List of selectors

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBarplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
