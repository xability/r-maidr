# Base R Cumulative Periodogram Processor

Reads [`cpgram()`](https://rdrr.io/r/stats/cpgram.html) as the staircase
it draws: the cumulative periodogram against frequency, held across each
interval and then jumping.

**It is a step, not a line.**
[`cpgram()`](https://rdrr.io/r/stats/cpgram.html) plots with
`type = "s"`, which draws the horizontal segment first – MAIDR's `"hv"`.
A line would imply the value slides between frequencies, which is not
what a cumulative sum does, and the export agrees: the grob is `step-1`,
not `lines-1`.

**It does NOT use
[`spectrum()`](https://rdrr.io/r/stats/spectrum.html)'s estimate.** This
is the trap the reading exists to avoid.
[`spectrum()`](https://rdrr.io/r/stats/spectrum.html) defaults to
`taper = 0.1, detrend = TRUE, demean = FALSE` and smooths;
[`cpgram()`](https://rdrr.io/r/stats/cpgram.html) computes its own
periodogram – taper, FFT, zero the first ordinate, then normalise the
cumulative sum – and the two disagree. Measured, the second step of the
drawn curve is 0.0801 while
[`spectrum()`](https://rdrr.io/r/stats/spectrum.html)'s estimate gives
0.0817: close enough to look right and wrong enough to announce wrong
numbers. So the computation below is
[`cpgram()`](https://rdrr.io/r/stats/cpgram.html)'s own, and it
reproduces the traced `plot.xy` call exactly.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRCpgramLayerProcessor`

## Methods

### Public methods

- [`BaseRCpgramLayerProcessor$process()`](#method-BaseRCpgramLayerProcessor-process)

- [`BaseRCpgramLayerProcessor$clone()`](#method-BaseRCpgramLayerProcessor-clone)

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

### `BaseRCpgramLayerProcessor$process()`

Emit the cumulative periodogram as a step

#### Usage

    BaseRCpgramLayerProcessor$process(
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

A step layer, or NULL when nothing was read

------------------------------------------------------------------------

### `BaseRCpgramLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRCpgramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
