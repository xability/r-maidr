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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

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

  Unused; present for the processor interface

- `layout`:

  Unused; present for the processor interface

- `built`:

  Unused; present for the processor interface

- `gt`:

  Gtable of the replayed drawing, searched for selectors (optional)

- `layer_info`:

  Layer information with the recorded call

#### Returns

List describing the layer for the MAIDR payload

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$extract_data()`

One series per row of the recorded height matrix

#### Usage

    BaseRDodgedBarLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of series

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$generate_selectors()`

The selector for the bars, scoped to this layer's plot group

#### Usage

    BaseRDodgedBarLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$find_rect_grobs()`

Find the rect grobs drawn by the recorded call at `call_index`

#### Usage

    BaseRDodgedBarLayerProcessor$find_rect_grobs(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$generate_selectors_from_grob()`

Build this layer's selector from the grob tree

#### Usage

    BaseRDodgedBarLayerProcessor$generate_selectors_from_grob(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

A selector string, or an empty string when no grob matches

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

Same shape as the stacked processor: `barplot(beside = TRUE)` writes no
title, its points carry the column category on x and the bar height on
y, and the group each bar belongs to travels with the point as z rather
than as a named axis.

#### Usage

    BaseRDodgedBarLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRDodgedBarLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRDodgedBarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRDodgedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
