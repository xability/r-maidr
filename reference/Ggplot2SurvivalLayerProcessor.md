# ggplot2 Kaplan-Meier Layer Processor

Reads a
[`maidr_survival()`](https://r.maidr.ai/reference/maidr_survival.md)
layer as the `survival` trace: one series per stratum, each point a row
of the layer, with `censored` where a subject left the study at that
time and the band's `yMin` and `yMax` when the layer draws it.

A Kaplan-Meier curve is a step chart, so the step processor does the
work – the rows in drawn order, the series split, the x and y read back
through the scales, `stepDirection` (always `"hv"`). What this adds is
what the trace reads that a step does not, and where the curve is.

- **Censoring and the band travel with the points.** `GeomSurvival`
  names `censored`, `ymin` and `ymax` as aesthetics, so they survive the
  build as columns. The rows the step processor emitted points for are
  found again by the same panel filter, drawn order, group split and
  `NA` span, and each value is put beside its point; a series whose
  count disagrees gets nothing rather than another row's.

- **The curve is found in the layer's own tree.** `GeomSurvival` draws
  its band, curve and marks as one grob tree named after the geom, the
  curve a bare polyline with one line per stratum. The tree is found by
  the layer's slot in the panel and the polyline inside it, so no other
  layer's polyline can be taken for it, nor it for theirs.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\>
[`Ggplot2StepLayerProcessor`](https://r.maidr.ai/reference/Ggplot2StepLayerProcessor.md)
-\> `Ggplot2SurvivalLayerProcessor`

## Methods

### Public methods

- [`Ggplot2SurvivalLayerProcessor$process()`](#method-Ggplot2SurvivalLayerProcessor-process)

- [`Ggplot2SurvivalLayerProcessor$attach_survival()`](#method-Ggplot2SurvivalLayerProcessor-attach_survival)

- [`Ggplot2SurvivalLayerProcessor$find_layer_polyline_grob()`](#method-Ggplot2SurvivalLayerProcessor-find_layer_polyline_grob)

- [`Ggplot2SurvivalLayerProcessor$clone()`](#method-Ggplot2SurvivalLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
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
- [`Ggplot2StepLayerProcessor$extract_step_direction()`](https://r.maidr.ai/reference/Ggplot2StepLayerProcessor.html#method-extract_step_direction)
- [`Ggplot2StepLayerProcessor$in_drawn_order()`](https://r.maidr.ai/reference/Ggplot2StepLayerProcessor.html#method-in_drawn_order)

------------------------------------------------------------------------

### `Ggplot2SurvivalLayerProcessor$process()`

Process the Kaplan-Meier layer

#### Usage

    Ggplot2SurvivalLayerProcessor$process(
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

### `Ggplot2SurvivalLayerProcessor$attach_survival()`

Attach each point's censoring and, when the band is drawn, its bounds

#### Usage

    Ggplot2SurvivalLayerProcessor$attach_survival(
      data,
      built,
      panel_id = NULL,
      band = FALSE
    )

#### Arguments

- `data`:

  The series the step processor emitted

- `built`:

  Built plot data, in drawn order

- `panel_id`:

  Panel ID for faceted plots (optional)

- `band`:

  Whether the layer draws the band

#### Returns

The series, with `censored`, `yMin` and `yMax` where they apply

------------------------------------------------------------------------

### `Ggplot2SurvivalLayerProcessor$find_layer_polyline_grob()`

The curve's polyline, inside this layer's own grob tree

#### Usage

    Ggplot2SurvivalLayerProcessor$find_layer_polyline_grob(
      plot,
      panel_grob,
      target = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

- `target`:

  Index of the layer to find; defaults to this one's

#### Returns

The polyline grob, or NULL when the tree holds anything but one

------------------------------------------------------------------------

### `Ggplot2SurvivalLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2SurvivalLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
