# Heatmap Layer Processor

Processes heatmap layers (geom_tile) with generic data and grob
reordering

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2HeatmapLayerProcessor`

## Methods

### Public methods

- [`Ggplot2HeatmapLayerProcessor$process()`](#method-Ggplot2HeatmapLayerProcessor-process)

- [`Ggplot2HeatmapLayerProcessor$needs_reordering()`](#method-Ggplot2HeatmapLayerProcessor-needs_reordering)

- [`Ggplot2HeatmapLayerProcessor$reorder_layer_data()`](#method-Ggplot2HeatmapLayerProcessor-reorder_layer_data)

- [`Ggplot2HeatmapLayerProcessor$extract_data()`](#method-Ggplot2HeatmapLayerProcessor-extract_data)

- [`Ggplot2HeatmapLayerProcessor$generate_selectors()`](#method-Ggplot2HeatmapLayerProcessor-generate_selectors)

- [`Ggplot2HeatmapLayerProcessor$clone()`](#method-Ggplot2HeatmapLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$process()`

#### Usage

    Ggplot2HeatmapLayerProcessor$process(
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

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$needs_reordering()`

#### Usage

    Ggplot2HeatmapLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$reorder_layer_data()`

#### Usage

    Ggplot2HeatmapLayerProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$extract_data()`

#### Usage

    Ggplot2HeatmapLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$generate_selectors()`

#### Usage

    Ggplot2HeatmapLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2HeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
