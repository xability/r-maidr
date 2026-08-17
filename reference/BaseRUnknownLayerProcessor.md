# Base R Unknown Layer Processor

Processes unknown Base R layer types as a fallback

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRUnknownLayerProcessor`

## Methods

### Public methods

- [`BaseRUnknownLayerProcessor$process()`](#method-BaseRUnknownLayerProcessor-process)

- [`BaseRUnknownLayerProcessor$needs_reordering()`](#method-BaseRUnknownLayerProcessor-needs_reordering)

- [`BaseRUnknownLayerProcessor$extract_data()`](#method-BaseRUnknownLayerProcessor-extract_data)

- [`BaseRUnknownLayerProcessor$generate_selectors()`](#method-BaseRUnknownLayerProcessor-generate_selectors)

- [`BaseRUnknownLayerProcessor$clone()`](#method-BaseRUnknownLayerProcessor-clone)

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
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$process()`

#### Usage

    BaseRUnknownLayerProcessor$process(
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

### `BaseRUnknownLayerProcessor$needs_reordering()`

#### Usage

    BaseRUnknownLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$extract_data()`

#### Usage

    BaseRUnknownLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$generate_selectors()`

#### Usage

    BaseRUnknownLayerProcessor$generate_selectors(layer_info)

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRUnknownLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
