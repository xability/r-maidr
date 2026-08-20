# Base R Step Plot Layer Processor

Processes Base R stairstep layers – `plot(x, y, type = "s")`,
`plot(x, y, type = "S")` and the
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md)
equivalents. A step chart is piecewise constant: the value is held
across an interval and then jumps, rather than being interpolated
between samples the way a line implies.

Data extraction, axis titles, the main title and polyline selector
generation are identical to a line layer, so this class inherits
`BaseRLineLayerProcessor` and adds only the step-specific reporting: the
layer `type` and the `stepDirection` convention the call requested.

One data point is emitted per data *sample*, never one per stairstep
vertex – the MAIDR frontend maps the rendered polyline's corner vertices
back onto the samples itself.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRStepLayerProcessor`

## Methods

### Public methods

- [`BaseRStepLayerProcessor$process()`](#method-BaseRStepLayerProcessor-process)

- [`BaseRStepLayerProcessor$extract_step_direction()`](#method-BaseRStepLayerProcessor-extract_step_direction)

- [`BaseRStepLayerProcessor$selector_grob_type()`](#method-BaseRStepLayerProcessor-selector_grob_type)

- [`BaseRStepLayerProcessor$clone()`](#method-BaseRStepLayerProcessor-clone)

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

------------------------------------------------------------------------

### `BaseRStepLayerProcessor$process()`

Process the step layer.

#### Usage

    BaseRStepLayerProcessor$process(
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

  Unused for Base R (kept for interface compatibility)

- `layout`:

  Unused for Base R (kept for interface compatibility)

- `built`:

  Unused for Base R (kept for interface compatibility)

- `gt`:

  Gtable object used for selector generation (optional)

- `grob_id`:

  Unused for Base R

- `panel_id`:

  Unused for Base R

- `panel_ctx`:

  Unused for Base R

- `layer_info`:

  Information about the recorded plot call

#### Returns

List with data, selectors, type, title, axes and stepDirection

------------------------------------------------------------------------

### `BaseRStepLayerProcessor$extract_step_direction()`

Read the step convention the recorded call requested.

`type = "s"` draws the horizontal segment first (MAIDR's `"hv"`) and
`type = "S"` draws the vertical segment first (`"vh"`). The two are not
interchangeable, so an unrecognised or absent `type` yields NULL and the
caller omits `stepDirection` rather than guessing.

#### Usage

    BaseRStepLayerProcessor$extract_step_direction(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

"hv", "vh", or NULL

------------------------------------------------------------------------

### `BaseRStepLayerProcessor$selector_grob_type()`

Draw a step layer's selectors from the stairstep grobs.

gridGraphics names a grob after the `type` letter that drew it, so a
stairstep lands under `graphics-plot-N-step-M` (`type = "s"`) or
`graphics-plot-N-Step-M` (`type = "S"`) – never under the `-lines-` name
the inherited line search looks for. Without this override a Base R step
layer emits zero selectors, and the frontend's
`selectors.length === series count` precondition then drops the layer's
highlighting entirely.

#### Usage

    BaseRStepLayerProcessor$selector_grob_type(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

"step"

------------------------------------------------------------------------

### `BaseRStepLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStepLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
