# Base R Point/Scatter Plot Layer Processor

Processes Base R scatter plot layers based on recorded plot calls

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRPointLayerProcessor`

## Methods

### Public methods

- [`BaseRPointLayerProcessor$process()`](#method-BaseRPointLayerProcessor-process)

- [`BaseRPointLayerProcessor$needs_reordering()`](#method-BaseRPointLayerProcessor-needs_reordering)

- [`BaseRPointLayerProcessor$extract_data()`](#method-BaseRPointLayerProcessor-extract_data)

- [`BaseRPointLayerProcessor$extract_axis_titles()`](#method-BaseRPointLayerProcessor-extract_axis_titles)

- [`BaseRPointLayerProcessor$extract_base_r_axis_grid_info()`](#method-BaseRPointLayerProcessor-extract_base_r_axis_grid_info)

- [`BaseRPointLayerProcessor$extract_main_title()`](#method-BaseRPointLayerProcessor-extract_main_title)

- [`BaseRPointLayerProcessor$generate_selectors()`](#method-BaseRPointLayerProcessor-generate_selectors)

- [`BaseRPointLayerProcessor$clone()`](#method-BaseRPointLayerProcessor-clone)

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
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$process()`

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

### `BaseRPointLayerProcessor$needs_reordering()`

#### Usage

    BaseRPointLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_data()`

#### Usage

    BaseRPointLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRPointLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_base_r_axis_grid_info()`

#### Usage

    BaseRPointLayerProcessor$extract_base_r_axis_grid_info(data, lim = NULL)

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_main_title()`

#### Usage

    BaseRPointLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$generate_selectors()`

#### Usage

    BaseRPointLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPointLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
