# Base R Spectral Density Processor

Reads [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the line it draws: the estimated spectral density against frequency.

**The values are the raw `spec`, not its logarithm.** `plot.spec` draws
on a log y axis by default, but it puts the log on the *axis* and hands
`plot.xy` the untransformed values – traced, the first call's `y` equals
`spectrum(v, plot = FALSE)$spec` exactly. So the numbers a reader hears
are the numbers the chart is scaled from, and taking a logarithm here
would announce a series the caller never computed.

**The caller's arguments are forwarded.** `spans`, `taper`, `detrend`
and the rest change the estimate, so recomputing with defaults would
announce a different curve from the one drawn. The recorded call's
arguments are passed through with `plot = FALSE` added.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRSpectrumLayerProcessor`

## Methods

### Public methods

- [`BaseRSpectrumLayerProcessor$process()`](#method-BaseRSpectrumLayerProcessor-process)

- [`BaseRSpectrumLayerProcessor$clone()`](#method-BaseRSpectrumLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$axis_extent()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-axis_extent)
- [`BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
- [`BaseRLineLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_axis_titles)
- [`BaseRLineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_data)
- [`BaseRLineLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_main_title)
- [`BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`BaseRLineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors)
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)
- [`BaseRLineLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRSpectrumLayerProcessor$process()`

Emit the spectral density as a line

#### Usage

    BaseRSpectrumLayerProcessor$process(
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

  Unused; present for the processor interface.

- `layout`:

  Unused; present for the processor interface.

- `built`:

  Unused; present for the processor interface.

- `gt`:

  Unused; the selector is built rather than searched for.

- `grob_id`:

  Unused; present for the processor interface.

- `panel_id`:

  Unused; present for the processor interface.

- `panel_ctx`:

  Unused; present for the processor interface.

- `layer_info`:

  Layer information with the recorded call.

#### Returns

A line layer, or NULL when nothing was read

------------------------------------------------------------------------

### `BaseRSpectrumLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSpectrumLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
