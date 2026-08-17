# Base R Dodged Bar Layer Processor

Processes Base R dodged bar plot layers with proper ordering to match
backend logic

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRDodgedBarLayerProcessor`

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
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$process()`

#### Usage

    BaseRDodgedBarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
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

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$extract_data()`

#### Usage

    BaseRDodgedBarLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$generate_selectors()`

#### Usage

    BaseRDodgedBarLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$find_rect_grobs()`

#### Usage

    BaseRDodgedBarLayerProcessor$find_rect_grobs(grob, call_index)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$generate_selectors_from_grob()`

#### Usage

    BaseRDodgedBarLayerProcessor$generate_selectors_from_grob(grob, call_index)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRDodgedBarLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$extract_main_title()`

#### Usage

    BaseRDodgedBarLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRDodgedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
