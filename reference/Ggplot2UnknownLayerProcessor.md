# Unknown Layer Processor

Handles unsupported layer types gracefully by returning empty data

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2UnknownLayerProcessor`

## Methods

### Public methods

- [`Ggplot2UnknownLayerProcessor$process()`](#method-Ggplot2UnknownLayerProcessor-process)

- [`Ggplot2UnknownLayerProcessor$extract_data()`](#method-Ggplot2UnknownLayerProcessor-extract_data)

- [`Ggplot2UnknownLayerProcessor$generate_selectors()`](#method-Ggplot2UnknownLayerProcessor-generate_selectors)

- [`Ggplot2UnknownLayerProcessor$clone()`](#method-Ggplot2UnknownLayerProcessor-clone)

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

    Ggplot2UnknownLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2UnknownLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL
    )

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2UnknownLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2UnknownLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
