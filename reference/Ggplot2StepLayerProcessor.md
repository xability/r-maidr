# ggplot2 Step Layer Processor

ggplot2 Step Layer Processor

ggplot2 Step Layer Processor

## Details

Processes
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
layers. A step chart is piecewise constant: the value is held across an
interval and then jumps, rather than being interpolated between samples
the way a line implies. The canonical case is a hypnogram – an ordinal
sleep stage (Awake / REM / N1 / N2 / N3) against time.

Everything about extracting x/y and locating the rendered polyline is
the same as for a line, so this class inherits
`Ggplot2LineLayerProcessor` and adds only what a step layer has that a
line layer does not:

- `stepDirection` – the `hv` / `vh` / `mid` convention the layer was
  drawn with, emitted as a sibling of `axes` and `data` on the layer.

- a per-point `label` – the *name* of the ordinal level, so the frontend
  announces "REM" rather than the numeric level code that encodes it.
  `y` stays numeric because it drives sonification, braille and the
  min/max range.

One data point is emitted per data *sample*, never one per stairstep
vertex. `ggplot2` expands the stairsteps inside `GeomStep$draw_panel()`,
so the rendered polyline carries `2n - 1` vertices (`hv` / `vh`) or `2n`
(`mid`) for `n` samples; the MAIDR frontend's `StepTrace` maps those
vertices back onto the samples. Emitting vertex-level data to "match"
the polyline would double every level and misreport transitions and run
lengths.

## Super classes

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\>
[`maidr::Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\> `Ggplot2StepLayerProcessor`

## Methods

### Public methods

- [`Ggplot2StepLayerProcessor$process()`](#method-Ggplot2StepLayerProcessor-process)

- [`Ggplot2StepLayerProcessor$extract_step_direction()`](#method-Ggplot2StepLayerProcessor-extract_step_direction)

- [`Ggplot2StepLayerProcessor$clone()`](#method-Ggplot2StepLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`maidr::Ggplot2LineLayerProcessor$attach_discrete_y_names()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_discrete_y_names)
- [`maidr::Ggplot2LineLayerProcessor$attach_group_axis()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_group_axis)
- [`maidr::Ggplot2LineLayerProcessor$attach_level_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_level_labels)
- [`maidr::Ggplot2LineLayerProcessor$build_level_lookup()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-build_level_lookup)
- [`maidr::Ggplot2LineLayerProcessor$curve_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-curve_selectors)
- [`maidr::Ggplot2LineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_data)
- [`maidr::Ggplot2LineLayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_layer_axes)
- [`maidr::Ggplot2LineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_multiline_data)
- [`maidr::Ggplot2LineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_single_line_data)
- [`maidr::Ggplot2LineLayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_layer_polyline_grob)
- [`maidr::Ggplot2LineLayerProcessor$find_main_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_main_polyline_grob)
- [`maidr::Ggplot2LineLayerProcessor$format_x_value()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-format_x_value)
- [`maidr::Ggplot2LineLayerProcessor$generate_multiline_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_multiline_selectors)
- [`maidr::Ggplot2LineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_selectors)
- [`maidr::Ggplot2LineLayerProcessor$generate_single_line_selector()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_single_line_selector)
- [`maidr::Ggplot2LineLayerProcessor$get_group_column()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_group_column)
- [`maidr::Ggplot2LineLayerProcessor$get_layer()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_layer)
- [`maidr::Ggplot2LineLayerProcessor$get_x_transformation()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_x_transformation)
- [`maidr::Ggplot2LineLayerProcessor$has_series_groups()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-has_series_groups)
- [`maidr::Ggplot2LineLayerProcessor$layer_polyline_grobs()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-layer_polyline_grobs)
- [`maidr::Ggplot2LineLayerProcessor$line_layer_position()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-line_layer_position)
- [`maidr::Ggplot2LineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-needs_reordering)
- [`maidr::Ggplot2LineLayerProcessor$normalize_point_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-normalize_point_values)
- [`maidr::Ggplot2LineLayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-other_geom_grob_prefixes)
- [`maidr::Ggplot2LineLayerProcessor$panel_axis_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-panel_axis_labels)
- [`maidr::Ggplot2LineLayerProcessor$polyline_curve_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-polyline_curve_count)
- [`maidr::Ggplot2LineLayerProcessor$recover_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-recover_x_values)
- [`maidr::Ggplot2LineLayerProcessor$resolve_group_mapping()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-resolve_group_mapping)
- [`maidr::Ggplot2LineLayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-resolve_panel_index)
- [`maidr::Ggplot2LineLayerProcessor$series_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-series_count)
- [`maidr::Ggplot2LineLayerProcessor$transform_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-transform_x_values)

------------------------------------------------------------------------

### Method `process()`

Process the step layer.

#### Usage

    Ggplot2StepLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data, selectors, title, axes, type and stepDirection

------------------------------------------------------------------------

### Method `extract_step_direction()`

Read the step convention this layer was drawn with.

`geom_step(direction = )` is a formal of `GeomStep$draw_panel()`, so
ggplot2 files it under `layer$geom_params$direction` rather than
`layer$aes_params` or the layer's mapping. The three accepted values
(`"hv"`, `"vh"`, `"mid"`) are exactly MAIDR's, so they pass through
unchanged. `"hv"` is both ggplot2's and MAIDR's default.

#### Usage

    Ggplot2StepLayerProcessor$extract_step_direction(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

One of "hv", "vh", "mid" (defaulting to "hv"), or NULL when the layer
cannot be located at all.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2StepLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
