# Base R Bar Plot Layer Processor

Processes Base R bar plot layers based on recorded plot calls

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRBarplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBarplotLayerProcessor$process()`](#method-BaseRBarplotLayerProcessor-process)

- [`BaseRBarplotLayerProcessor$is_horizontal()`](#method-BaseRBarplotLayerProcessor-is_horizontal)

- [`BaseRBarplotLayerProcessor$needs_reordering()`](#method-BaseRBarplotLayerProcessor-needs_reordering)

- [`BaseRBarplotLayerProcessor$extract_data()`](#method-BaseRBarplotLayerProcessor-extract_data)

- [`BaseRBarplotLayerProcessor$extract_axis_titles()`](#method-BaseRBarplotLayerProcessor-extract_axis_titles)

- [`BaseRBarplotLayerProcessor$extract_main_title()`](#method-BaseRBarplotLayerProcessor-extract_main_title)

- [`BaseRBarplotLayerProcessor$generate_selectors()`](#method-BaseRBarplotLayerProcessor-generate_selectors)

- [`BaseRBarplotLayerProcessor$find_rect_grobs()`](#method-BaseRBarplotLayerProcessor-find_rect_grobs)

- [`BaseRBarplotLayerProcessor$generate_selectors_from_grob()`](#method-BaseRBarplotLayerProcessor-generate_selectors_from_grob)

- [`BaseRBarplotLayerProcessor$clone()`](#method-BaseRBarplotLayerProcessor-clone)

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

### `BaseRBarplotLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

#### Usage

    BaseRBarplotLayerProcessor$process(
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

### `BaseRBarplotLayerProcessor$is_horizontal()`

Check whether this barplot call used horiz = TRUE

#### Usage

    BaseRBarplotLayerProcessor$is_horizontal(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Logical

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing; a Base R layer
is read from the recorded call and never is

#### Usage

    BaseRBarplotLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$extract_data()`

One point per bar, read from the recorded `height`

#### Usage

    BaseRBarplotLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of points

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes no
title of its own, so an author who wrote none leaves both axes nameless.
A bar chart always plots categories against their measured heights,
whether or not the heights arrived named, so that is what the defaults
say. `horiz = TRUE` puts the heights on the visual x axis – the same
swap extract_data() applies to the points.

#### Usage

    BaseRBarplotLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRBarplotLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$generate_selectors()`

Generate the CSS selectors that address this layer's drawn elements

#### Usage

    BaseRBarplotLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$find_rect_grobs()`

Recursively find rect grobs in the grob tree (like ggplot2 does)

#### Usage

    BaseRBarplotLayerProcessor$find_rect_grobs(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  The plot call index to match

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$generate_selectors_from_grob()`

Generate selectors from grob tree (like ggplot2 does)

#### Usage

    BaseRBarplotLayerProcessor$generate_selectors_from_grob(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  The plot call index

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBarplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
