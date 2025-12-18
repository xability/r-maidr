# Smooth Layer Processor

Processes smooth plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2SmoothLayerProcessor`

## Methods

### Public methods

- [`Ggplot2SmoothLayerProcessor$process()`](#method-Ggplot2SmoothLayerProcessor-process)

- [`Ggplot2SmoothLayerProcessor$extract_data()`](#method-Ggplot2SmoothLayerProcessor-extract_data)

- [`Ggplot2SmoothLayerProcessor$generate_selectors()`](#method-Ggplot2SmoothLayerProcessor-generate_selectors)

- [`Ggplot2SmoothLayerProcessor$clone()`](#method-Ggplot2SmoothLayerProcessor-clone)

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

    Ggplot2SmoothLayerProcessor$process(plot, layout, built = NULL, gt = NULL)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2SmoothLayerProcessor$extract_data(plot, built = NULL)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2SmoothLayerProcessor$generate_selectors(plot, gt = NULL)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2SmoothLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
