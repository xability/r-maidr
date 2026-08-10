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

- [`Ggplot2StepLayerProcessor$extract_data()`](#method-Ggplot2StepLayerProcessor-extract_data)

- [`Ggplot2StepLayerProcessor$normalize_point_values()`](#method-Ggplot2StepLayerProcessor-normalize_point_values)

- [`Ggplot2StepLayerProcessor$build_level_lookup()`](#method-Ggplot2StepLayerProcessor-build_level_lookup)

- [`Ggplot2StepLayerProcessor$get_original_y_column()`](#method-Ggplot2StepLayerProcessor-get_original_y_column)

- [`Ggplot2StepLayerProcessor$attach_level_labels()`](#method-Ggplot2StepLayerProcessor-attach_level_labels)

- [`Ggplot2StepLayerProcessor$get_layer()`](#method-Ggplot2StepLayerProcessor-get_layer)

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
- [`maidr::Ggplot2LineLayerProcessor$attach_group_axis()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_group_axis)
- [`maidr::Ggplot2LineLayerProcessor$curve_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-curve_selectors)
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
- [`maidr::Ggplot2LineLayerProcessor$get_original_x_column()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_original_x_column)
- [`maidr::Ggplot2LineLayerProcessor$get_x_transformation()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_x_transformation)
- [`maidr::Ggplot2LineLayerProcessor$has_series_groups()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-has_series_groups)
- [`maidr::Ggplot2LineLayerProcessor$layer_polyline_grobs()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-layer_polyline_grobs)
- [`maidr::Ggplot2LineLayerProcessor$line_layer_position()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-line_layer_position)
- [`maidr::Ggplot2LineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-needs_reordering)
- [`maidr::Ggplot2LineLayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-other_geom_grob_prefixes)
- [`maidr::Ggplot2LineLayerProcessor$polyline_curve_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-polyline_curve_count)
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

### Method `extract_data()`

Extract step data, one point per data sample.

Delegates to the line processor for x/y extraction – including the
recovery of Date / POSIXct x columns and the dropping of NA-y rows,
which exists so the emitted data length stays aligned with the rendered
geometry – then attaches the ordinal level name to each point.

#### Usage

    Ggplot2StepLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List of series, each a list of points with x, y and optionally z and
label

------------------------------------------------------------------------

### Method `normalize_point_values()`

Coerce every point's y to a plain number.

A discrete y aesthetic – the ordinal level of a hypnogram, and the
reason this processor exists – makes
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
return y as a `mapped_discrete` vector. That class carries no `asJSON`
method, so emitting it verbatim aborts payload serialisation with "No
method asJSON S3 class: mapped_discrete". Stripping the class here keeps
y a bare number, which is what the wire contract asks for and what
drives sonification, braille and the min/max range.

#### Usage

    Ggplot2StepLayerProcessor$normalize_point_values(series_data)

#### Arguments

- `series_data`:

  List of series produced by the line extractor

#### Returns

The series list with numeric y values

------------------------------------------------------------------------

### Method `build_level_lookup()`

Build a numeric-level to level-name lookup for the y aesthetic.

For a factor (or character) y aesthetic,
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
replaces the level with its numeric position, so `built$data$y` is a
level *code* and the name only survives in the original column. The
lookup is keyed by the built y value and built from the full, unfiltered
pair of columns, so it stays correct no matter which rows survive
NA-dropping or panel filtering downstream.

Returns NULL for a plain continuous y, in which case no `label` is
emitted and the frontend announces the numeric value.

#### Usage

    Ggplot2StepLayerProcessor$build_level_lookup(plot, built)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

#### Returns

Named character vector keyed by the built y value, or NULL

------------------------------------------------------------------------

### Method `get_original_y_column()`

Recover the original (untransformed) y column for a layer.

Mirrors `get_original_x_column()`: looks up the y mapping on the layer
first and then on the plot, and searches the layer's own `data` before
the plot's. Returns the per-row vector aligned to `built_data` when a
simple column reference is found and the lengths match, otherwise NULL.

#### Usage

    Ggplot2StepLayerProcessor$get_original_y_column(plot, built_data)

#### Arguments

- `plot`:

  The ggplot2 object

- `built_data`:

  The built data frame for this layer

#### Returns

The original y column, or NULL

------------------------------------------------------------------------

### Method `attach_level_labels()`

Attach the ordinal level name to every point of every series. Points
whose y has no entry in the lookup are left untouched, so the frontend
falls back to the numeric announcement for them.

#### Usage

    Ggplot2StepLayerProcessor$attach_level_labels(series_data, lookup)

#### Arguments

- `series_data`:

  List of series produced by the line extractor

- `lookup`:

  Named character vector keyed by the built y value

#### Returns

The series list with `label` attached where known

------------------------------------------------------------------------

### Method `get_layer()`

The ggplot2 layer this processor is responsible for.

#### Usage

    Ggplot2StepLayerProcessor$get_layer(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

The layer, or NULL when the index does not resolve

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2StepLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
