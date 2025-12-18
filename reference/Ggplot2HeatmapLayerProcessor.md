# Heatmap Layer Processor

Processes heatmap layers (geom_tile) with generic data and grob
reordering

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2HeatmapLayerProcessor`

## Methods

### Public methods

- [`Ggplot2HeatmapLayerProcessor$process()`](#method-Ggplot2HeatmapLayerProcessor-process)

- [`Ggplot2HeatmapLayerProcessor$needs_reordering()`](#method-Ggplot2HeatmapLayerProcessor-needs_reordering)

- [`Ggplot2HeatmapLayerProcessor$reorder_layer_data()`](#method-Ggplot2HeatmapLayerProcessor-reorder_layer_data)

- [`Ggplot2HeatmapLayerProcessor$extract_data()`](#method-Ggplot2HeatmapLayerProcessor-extract_data)

- [`Ggplot2HeatmapLayerProcessor$generate_selectors()`](#method-Ggplot2HeatmapLayerProcessor-generate_selectors)

- [`Ggplot2HeatmapLayerProcessor$clone()`](#method-Ggplot2HeatmapLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2HeatmapLayerProcessor$process(plot, layout, built = NULL, gt = NULL)

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    Ggplot2HeatmapLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `reorder_layer_data()`

#### Usage

    Ggplot2HeatmapLayerProcessor$reorder_layer_data(data, plot)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2HeatmapLayerProcessor$extract_data(plot, built = NULL)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2HeatmapLayerProcessor$generate_selectors(plot, gt = NULL)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2HeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
