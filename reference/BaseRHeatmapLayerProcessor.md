# Base R Heatmap Layer Processor

Processes Base R heatmap layers using the heatmap() function

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRHeatmapLayerProcessor`

## Methods

### Public methods

- [`BaseRHeatmapLayerProcessor$process()`](#method-BaseRHeatmapLayerProcessor-process)

- [`BaseRHeatmapLayerProcessor$extract_data()`](#method-BaseRHeatmapLayerProcessor-extract_data)

- [`BaseRHeatmapLayerProcessor$image_axis_names()`](#method-BaseRHeatmapLayerProcessor-image_axis_names)

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

### `BaseRHeatmapLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

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

### `BaseRHeatmapLayerProcessor$extract_data()`

One row per cell of the recorded matrix, in drawn order

#### Usage

    BaseRHeatmapLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of rows

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$image_axis_names()`

The names the
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls drawn
on an [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md) give
its cells

`image(z)` centres its cells on `seq(0, 1, length.out = n)` along each
axis and writes no names there. The
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls drawn
on that side of the same plot name the cells when their `labels` put a
name at the centre of every cell: the reader is told "Day is Tue, Hour
is 9am" where they heard "Day is 2, Hour is 1". Several calls on one
side are read together, a later name at a centre written over an earlier
one, as R draws it. Calls that name some cells and not others name none
of them, as a value between ticks has no name of its own.

Only `image(z)`'s own centres are read. An `image(x, y, z)` given its
coordinates is not read as a heat map here at all (`extract_data()`
finds no matrix in `x`), so it has no cells to name.

#### Usage

    BaseRHeatmapLayerProcessor$image_axis_names(layer_info, side, cells)

#### Arguments

- `layer_info`:

  Layer information with the recorded call and its plot group

- `side`:

  The axis: 1 for x, 2 for y

- `cells`:

  How many cells run along it

#### Returns

One name per cell, from the low end of the axis, or NULL

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

Selectors for the image tiles, one per cell

#### Usage

    BaseRHeatmapLayerProcessor$generate_selectors(
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

### `BaseRHeatmapLayerProcessor$find_image_rect_grobs()`

Find the image-rect grobs drawn by the plot group at `group_index`

#### Usage

    BaseRHeatmapLayerProcessor$find_image_rect_grobs(grob, group_index)

#### Arguments

- `grob`:

  The grob tree to search

- `group_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$generate_selectors_from_grob()`

Build this layer's selector from the grob tree

#### Usage

    BaseRHeatmapLayerProcessor$generate_selectors_from_grob(
      grob,
      group_index = NULL
    )

#### Arguments

- `grob`:

  The grob tree to search

- `group_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

A selector string, or an empty string when no grob matches

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

[`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) lays the
matrix out one way round only – its columns run along x and its rows up
y – so those two words are facts about the call.
[`image()`](https://r.maidr.ai/reference/base-r-wrappers.md) is not the
same picture: it draws a coordinate grid, and `image(x, y, z)` puts the
caller's own coordinates on those axes, so naming them after a matrix
would be a guess. It gets no default.

#### Usage

    BaseRHeatmapLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRHeatmapLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRHeatmapLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRHeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
