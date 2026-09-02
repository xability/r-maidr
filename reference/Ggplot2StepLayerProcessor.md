# ggplot2 Step Layer Processor

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

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\> `Ggplot2StepLayerProcessor`

## Methods

### Public methods

- [`Ggplot2StepLayerProcessor$process()`](#method-Ggplot2StepLayerProcessor-process)

- [`Ggplot2StepLayerProcessor$in_drawn_order()`](#method-Ggplot2StepLayerProcessor-in_drawn_order)

- [`Ggplot2StepLayerProcessor$extract_step_direction()`](#method-Ggplot2StepLayerProcessor-extract_step_direction)

- [`Ggplot2StepLayerProcessor$clone()`](#method-Ggplot2StepLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
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
- [`Ggplot2LineLayerProcessor$attach_discrete_y_names()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_discrete_y_names)
- [`Ggplot2LineLayerProcessor$attach_group_axis()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_group_axis)
- [`Ggplot2LineLayerProcessor$attach_level_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_level_labels)
- [`Ggplot2LineLayerProcessor$build_level_lookup()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-build_level_lookup)
- [`Ggplot2LineLayerProcessor$curve_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-curve_selectors)
- [`Ggplot2LineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_data)
- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_layer_axes)
- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_multiline_data)
- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_single_line_data)
- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_main_polyline_grob)
- [`Ggplot2LineLayerProcessor$format_x_value()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-format_x_value)
- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_multiline_selectors)
- [`Ggplot2LineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_selectors)
- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_single_line_selector)
- [`Ggplot2LineLayerProcessor$get_group_column()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_group_column)
- [`Ggplot2LineLayerProcessor$get_layer()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_layer)
- [`Ggplot2LineLayerProcessor$get_x_transformation()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_x_transformation)
- [`Ggplot2LineLayerProcessor$has_series_groups()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-has_series_groups)
- [`Ggplot2LineLayerProcessor$line_layer_position()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-line_layer_position)
- [`Ggplot2LineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-needs_reordering)
- [`Ggplot2LineLayerProcessor$normalize_point_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-normalize_point_values)
- [`Ggplot2LineLayerProcessor$panel_axis_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-panel_axis_labels)
- [`Ggplot2LineLayerProcessor$polyline_curve_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-polyline_curve_count)
- [`Ggplot2LineLayerProcessor$recover_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-recover_x_values)
- [`Ggplot2LineLayerProcessor$resolve_group_mapping()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-resolve_group_mapping)
- [`Ggplot2LineLayerProcessor$series_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-series_count)
- [`Ggplot2LineLayerProcessor$transform_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-transform_x_values)

------------------------------------------------------------------------

### `Ggplot2StepLayerProcessor$process()`

Process the step layer.

#### Usage

    Ggplot2StepLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
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

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data, selectors, title, axes, type and stepDirection

------------------------------------------------------------------------

### `Ggplot2StepLayerProcessor$in_drawn_order()`

Put this layer's built rows into the order they are drawn in, dropping
any row that is not a point.

Both halves come from one fact: `GeomStep` does not draw the rows it is
handed. `GeomStep$draw_panel()` calls `ggplot2:::stairstep()`, whose
first act is `data[order(data$x), ]` – so the drawn staircase is the
*sorted* rows, whatever order the stat returned them in. Sorting here
recovers what is on screen rather than imposing a new order, and an
already-sorted layer – which is every
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
written by hand – is unchanged.

`StatEcdf` is why this is needed at all. It returns its rows in input
order and pads them with `-Inf` / `Inf` for the two ends of the
staircase. Measured on `n = 20`: 22 rows, two of them infinite,
unsorted. Those two rows are not observations – there is no x to
announce for them – and an infinity in the payload is worse than a
dropped point in both bindings: `jsonlite` writes it as the *string*
`"-Inf"`, and `json.dumps` on the Python side writes a bare `-Infinity`
that `JSON.parse` rejects outright (xability/py-maidr#427).

Ordered within `PANEL` and `group`, not globally, because `draw_panel()`
is called once per panel per group – a grouped ECDF is several
staircases, and a global sort would interleave them into one series that
walks backwards at every seam.

The filter asks about **x** alone, and deliberately. A row with a real x
and a missing y is a different thing – it has a position and no reading
– and the line processor this class inherits already drops those, for
its own unrelated reason: the rendered polyline carries coordinates only
for non-NA points, so keeping them would shift the highlight-to-point
index mapping. Repeating that here would be a second filter with a
second rationale over the same rows. Raised in review on \#169; the
Python binding draws the same x-only line, and for the same reason
(xability/py-maidr#430).

Left alone when x is not numeric: the finiteness test is meaningless
there and [`is.finite()`](https://rdrr.io/r/base/is.finite.html) on a
character vector is `FALSE` throughout, which would delete every row.

#### Usage

    Ggplot2StepLayerProcessor$in_drawn_order(built)

#### Arguments

- `built`:

  Built plot data

#### Returns

`built`, with this layer's frame reordered and filtered

------------------------------------------------------------------------

### `Ggplot2StepLayerProcessor$extract_step_direction()`

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

### `Ggplot2StepLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2StepLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
