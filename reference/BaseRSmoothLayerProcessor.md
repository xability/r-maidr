# Base R Smooth/Density Layer Processor

Processes Base R smooth curves including:

- Density plots: plot(density()) or lines(density())

- Loess smooth: lines(loess.smooth()) or lines(predict(loess))

- Smooth splines: lines(smooth.spline())

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRSmoothLayerProcessor`

## Methods

### Public methods

- [`BaseRSmoothLayerProcessor$process()`](#method-BaseRSmoothLayerProcessor-process)

- [`BaseRSmoothLayerProcessor$extract_data()`](#method-BaseRSmoothLayerProcessor-extract_data)

- [`BaseRSmoothLayerProcessor$generate_selectors()`](#method-BaseRSmoothLayerProcessor-generate_selectors)

- [`BaseRSmoothLayerProcessor$find_polyline_grobs()`](#method-BaseRSmoothLayerProcessor-find_polyline_grobs)

- [`BaseRSmoothLayerProcessor$generate_selectors_from_grob()`](#method-BaseRSmoothLayerProcessor-generate_selectors_from_grob)

- [`BaseRSmoothLayerProcessor$extract_axis_titles()`](#method-BaseRSmoothLayerProcessor-extract_axis_titles)

- [`BaseRSmoothLayerProcessor$extract_main_title()`](#method-BaseRSmoothLayerProcessor-extract_main_title)

- [`BaseRSmoothLayerProcessor$clone()`](#method-BaseRSmoothLayerProcessor-clone)

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

### `BaseRSmoothLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

#### Usage

    BaseRSmoothLayerProcessor$process(
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

### `BaseRSmoothLayerProcessor$extract_data()`

One point per fitted value of the smooth, density or curve

#### Usage

    BaseRSmoothLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of points

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$generate_selectors()`

The selector for the curve's polyline

#### Usage

    BaseRSmoothLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$find_polyline_grobs()`

Find the lines container grob for this layer

#### Usage

    BaseRSmoothLayerProcessor$find_polyline_grobs(grob, call_index = NULL)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

Grob name, or NULL

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$generate_selectors_from_grob()`

Build this layer's selector from the grob tree

#### Usage

    BaseRSmoothLayerProcessor$generate_selectors_from_grob(grob, call_index = NULL)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

A selector string, or an empty string when no grob matches

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

The x axis holds whatever variable was smoothed, which the recorded
arguments no longer name, so it carries no default. The y axis does when
the curve came from [`density()`](https://rdrr.io/r/stats/density.html):
that estimate is a density, and plot.density() prints exactly that word.

#### Usage

    BaseRSmoothLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRSmoothLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSmoothLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
