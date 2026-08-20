# Base R Heatmap Layer Processor

Processes Base R heatmap layers using the heatmap() function

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRHeatmapLayerProcessor`

## Methods

### Public methods

- [`BaseRHeatmapLayerProcessor$process()`](#method-BaseRHeatmapLayerProcessor-process)

- [`BaseRHeatmapLayerProcessor$extract_data()`](#method-BaseRHeatmapLayerProcessor-extract_data)

- [`BaseRHeatmapLayerProcessor$compute_heatmap_ordering()`](#method-BaseRHeatmapLayerProcessor-compute_heatmap_ordering)

- [`BaseRHeatmapLayerProcessor$generate_selectors()`](#method-BaseRHeatmapLayerProcessor-generate_selectors)

- [`BaseRHeatmapLayerProcessor$find_image_rect_grobs()`](#method-BaseRHeatmapLayerProcessor-find_image_rect_grobs)

- [`BaseRHeatmapLayerProcessor$generate_selectors_from_grob()`](#method-BaseRHeatmapLayerProcessor-generate_selectors_from_grob)

- [`BaseRHeatmapLayerProcessor$extract_axis_titles()`](#method-BaseRHeatmapLayerProcessor-extract_axis_titles)

- [`BaseRHeatmapLayerProcessor$extract_main_title()`](#method-BaseRHeatmapLayerProcessor-extract_main_title)

- [`BaseRHeatmapLayerProcessor$clone()`](#method-BaseRHeatmapLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$process()`

#### Usage

    BaseRHeatmapLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
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

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$extract_data()`

#### Usage

    BaseRHeatmapLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$compute_heatmap_ordering()`

Reproduce the row/column ordering heatmap() draws with

#### Usage

    BaseRHeatmapLayerProcessor$compute_heatmap_ordering(args)

#### Arguments

- `args`:

  Recorded heatmap() arguments

#### Returns

List with rowInd/colInd, or NULL if unavailable

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$generate_selectors()`

#### Usage

    BaseRHeatmapLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$find_image_rect_grobs()`

#### Usage

    BaseRHeatmapLayerProcessor$find_image_rect_grobs(grob, group_index)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$generate_selectors_from_grob()`

#### Usage

    BaseRHeatmapLayerProcessor$generate_selectors_from_grob(
      grob,
      group_index = NULL
    )

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRHeatmapLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$extract_main_title()`

#### Usage

    BaseRHeatmapLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRHeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
