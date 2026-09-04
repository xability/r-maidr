# Base R Histogram Layer Processor

Processes Base R histogram plot layers using verified data extraction
and selector generation logic.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRHistogramLayerProcessor`

## Methods

### Public methods

- [`BaseRHistogramLayerProcessor$process()`](#method-BaseRHistogramLayerProcessor-process)

- [`BaseRHistogramLayerProcessor$extract_data()`](#method-BaseRHistogramLayerProcessor-extract_data)

- [`BaseRHistogramLayerProcessor$recompute_histogram()`](#method-BaseRHistogramLayerProcessor-recompute_histogram)

- [`BaseRHistogramLayerProcessor$is_frequency()`](#method-BaseRHistogramLayerProcessor-is_frequency)

- [`BaseRHistogramLayerProcessor$generate_selectors()`](#method-BaseRHistogramLayerProcessor-generate_selectors)

- [`BaseRHistogramLayerProcessor$find_rect_grobs()`](#method-BaseRHistogramLayerProcessor-find_rect_grobs)

- [`BaseRHistogramLayerProcessor$generate_selectors_from_grob()`](#method-BaseRHistogramLayerProcessor-generate_selectors_from_grob)

- [`BaseRHistogramLayerProcessor$extract_axis_titles()`](#method-BaseRHistogramLayerProcessor-extract_axis_titles)

- [`BaseRHistogramLayerProcessor$frequency_label()`](#method-BaseRHistogramLayerProcessor-frequency_label)

- [`BaseRHistogramLayerProcessor$extract_main_title()`](#method-BaseRHistogramLayerProcessor-extract_main_title)

- [`BaseRHistogramLayerProcessor$clone()`](#method-BaseRHistogramLayerProcessor-clone)

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

### `BaseRHistogramLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

#### Usage

    BaseRHistogramLayerProcessor$process(
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

### `BaseRHistogramLayerProcessor$extract_data()`

One point per bin, from the histogram recomputed from the recorded call

#### Usage

    BaseRHistogramLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of points

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$recompute_histogram()`

Recompute the plotted histogram from the recorded call

#### Usage

    BaseRHistogramLayerProcessor$recompute_histogram(args)

#### Arguments

- `args`:

  Recorded argument list

#### Returns

A "histogram" object, or NULL when the call recorded no data

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$is_frequency()`

Is this a frequency histogram rather than a density one?

The plotted y-axis shows counts only for frequency histograms; with freq
= FALSE or probability = TRUE it shows densities. hist()'s own default
is freq = TRUE only for equidistant breaks.

#### Usage

    BaseRHistogramLayerProcessor$is_frequency(args, hist_obj = NULL)

#### Arguments

- `args`:

  Recorded argument list

- `hist_obj`:

  The recomputed histogram, or NULL when there is none

#### Returns

Logical

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$generate_selectors()`

The selector for the bins, scoped to this layer's plot group

#### Usage

    BaseRHistogramLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$find_rect_grobs()`

Find the rect grobs drawn by the recorded call at `call_index`

#### Usage

    BaseRHistogramLayerProcessor$find_rect_grobs(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$generate_selectors_from_grob()`

Build this layer's selector from the grob tree

#### Usage

    BaseRHistogramLayerProcessor$generate_selectors_from_grob(
      grob,
      call_index = NULL
    )

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  Index of the recorded plot group, which numbers the panel's grobs

#### Returns

A selector string, or an empty string when no grob matches

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

[`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) derives both
titles inside the call and so records neither: the x title is
`deparse(substitute(x))`, which is gone by the time the evaluated
arguments reach us, and the y title is "Frequency" or "Density"
depending on what the bars measure. The y default therefore repeats
hist()'s own choice – resolved by the same rule that decides which
values extract_data() emits, so the noun always names the number being
announced – while x says only what the axis certainly holds: the bins.

#### Usage

    BaseRHistogramLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$frequency_label()`

The title hist() itself would print above the counted axis

#### Usage

    BaseRHistogramLayerProcessor$frequency_label(args)

#### Arguments

- `args`:

  Recorded argument list

#### Returns

"Frequency" or "Density"

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRHistogramLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRHistogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
