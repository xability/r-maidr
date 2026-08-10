# Base R Step Plot Layer Processor

Base R Step Plot Layer Processor

Base R Step Plot Layer Processor

## Details

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

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\>
[`maidr::BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRStepLayerProcessor`

## Methods

### Public methods

- [`BaseRStepLayerProcessor$process()`](#method-BaseRStepLayerProcessor-process)

- [`BaseRStepLayerProcessor$extract_step_direction()`](#method-BaseRStepLayerProcessor-extract_step_direction)

- [`BaseRStepLayerProcessor$selector_grob_type()`](#method-BaseRStepLayerProcessor-selector_grob_type)

- [`BaseRStepLayerProcessor$clone()`](#method-BaseRStepLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`maidr::BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
- [`maidr::BaseRLineLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_axis_titles)
- [`maidr::BaseRLineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_data)
- [`maidr::BaseRLineLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_main_title)
- [`maidr::BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`maidr::BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`maidr::BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`maidr::BaseRLineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors)
- [`maidr::BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`maidr::BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`maidr::BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`maidr::BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`maidr::BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)

------------------------------------------------------------------------

### Method `process()`

Process the step layer.

#### Usage

    BaseRStepLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
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

- `scale_mapping`:

  Unused for Base R

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

### Method `extract_step_direction()`

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

### Method `selector_grob_type()`

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

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStepLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
