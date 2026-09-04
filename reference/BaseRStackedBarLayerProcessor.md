# Base R Stacked Bar Layer Processor

Processes Base R stacked bar plot layers intercepted via the patching
system. Assumes sorting by x (columns) and then z (rows) has already
been applied by the `SortingPatcher`.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRStackedBarLayerProcessor`

## Methods

### Public methods

- [`BaseRStackedBarLayerProcessor$process()`](#method-BaseRStackedBarLayerProcessor-process)

- [`BaseRStackedBarLayerProcessor$needs_reordering()`](#method-BaseRStackedBarLayerProcessor-needs_reordering)

- [`BaseRStackedBarLayerProcessor$extract_data()`](#method-BaseRStackedBarLayerProcessor-extract_data)

- [`BaseRStackedBarLayerProcessor$extract_axis_titles()`](#method-BaseRStackedBarLayerProcessor-extract_axis_titles)

- [`BaseRStackedBarLayerProcessor$extract_main_title()`](#method-BaseRStackedBarLayerProcessor-extract_main_title)

- [`BaseRStackedBarLayerProcessor$generate_selectors()`](#method-BaseRStackedBarLayerProcessor-generate_selectors)

- [`BaseRStackedBarLayerProcessor$find_rect_groups()`](#method-BaseRStackedBarLayerProcessor-find_rect_groups)

- [`BaseRStackedBarLayerProcessor$clone()`](#method-BaseRStackedBarLayerProcessor-clone)

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

### `BaseRStackedBarLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

#### Usage

    BaseRStackedBarLayerProcessor$process(
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

List describing the layer for the MAIDR payload

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing; a Base R layer
is read from the recorded call and never is

#### Usage

    BaseRStackedBarLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$extract_data()`

One series per row of the recorded height matrix

#### Usage

    BaseRStackedBarLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of series

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

A stacked [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
records no title unless the author wrote one, and its points always
carry the column category on x and the segment height on y, so the
defaults name those two. The stack's own dimension is already announced
per point as z; nothing in the call names the variable those groups came
from, so no z title is claimed.

#### Usage

    BaseRStackedBarLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRStackedBarLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$generate_selectors()`

The selector for the segments, scoped to this layer's plot group

#### Usage

    BaseRStackedBarLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

- `extracted_data`:

  The data already extracted for this layer (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$find_rect_groups()`

Find every rect group drawn by the plot group at `call_index`

#### Usage

    BaseRStackedBarLayerProcessor$find_rect_groups(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStackedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
