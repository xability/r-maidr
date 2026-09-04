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
- [`LayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_polyline_grob)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$layer_polyline_grobs()`](https://r.maidr.ai/reference/LayerProcessor.html#method-layer_polyline_grobs)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$process()`

Describe a layer nothing is known about

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

  Unused; present for the processor interface

- `layout`:

  Unused; present for the processor interface

- `built`:

  Unused; present for the processor interface

- `gt`:

  Gtable of the replayed drawing, searched for selectors (optional)

- `grob_id`:

  Unused; present for the processor interface

- `panel_id`:

  Unused; present for the processor interface

- `panel_ctx`:

  Unused; present for the processor interface

- `layer_info`:

  Layer information with the recorded call

#### Returns

List with no data and no selectors

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing; a Base R layer
is read from the recorded call and never is

#### Usage

    BaseRUnknownLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$extract_data()`

Nothing: an unknown layer has no data to announce

#### Usage

    BaseRUnknownLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Empty list

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$generate_selectors()`

Nothing: an unknown layer has no elements to address

#### Usage

    BaseRUnknownLayerProcessor$generate_selectors(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Empty list

------------------------------------------------------------------------

### `BaseRUnknownLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRUnknownLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
