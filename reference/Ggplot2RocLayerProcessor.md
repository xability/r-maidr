# ROC Curve Layer Processor

Reads a receiver operating characteristic curve – a classifier's true
positive rate against its false positive rate, one point per decision
threshold, one curve per classifier – as the `roc` trace.

Structurally a multi-series line, so the line processor does the work:
the series split, the x recovery through the scale, the selectors per
drawn polyline. What this adds is what the trace reads that a line does
not.

- **The rates are numbers.** The line processor formats x for
  announcement, which turns a rate into a string; the core's ROC trace
  measures the area under the curve and each point's height above the
  chance diagonal from `x`, so it is handed back as a number.

- **`x` is the false positive rate.**
  [`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html) maps
  `specificity` on a reversed axis, which draws the same picture as
  `1 - specificity` on an ordinary one and reads as the opposite: every
  point would be measured below the diagonal it sits above. The rate is
  inverted and the axis named for what is announced.

- **Thresholds and areas travel with the points.** A
  [`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) layer's
  `threshold` aesthetic survives the build as a column, and its `auc`
  argument names the areas; each is attached to the points of the series
  it belongs to, the threshold per point and the area on the first point
  of its curve, which is where the core reads it.

Emitted with `type = "roc"`, which the core has read since maidr 4.9.0.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\> `Ggplot2RocLayerProcessor`

## Methods

### Public methods

- [`Ggplot2RocLayerProcessor$process()`](#method-Ggplot2RocLayerProcessor-process)

- [`Ggplot2RocLayerProcessor$as_rates()`](#method-Ggplot2RocLayerProcessor-as_rates)

- [`Ggplot2RocLayerProcessor$attach_thresholds()`](#method-Ggplot2RocLayerProcessor-attach_thresholds)

- [`Ggplot2RocLayerProcessor$attach_areas()`](#method-Ggplot2RocLayerProcessor-attach_areas)

- [`Ggplot2RocLayerProcessor$rows_read()`](#method-Ggplot2RocLayerProcessor-rows_read)

- [`Ggplot2RocLayerProcessor$clone()`](#method-Ggplot2RocLayerProcessor-clone)

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

### `Ggplot2RocLayerProcessor$process()`

Process the ROC layer

#### Usage

    Ggplot2RocLayerProcessor$process(
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

List with data, selectors, title, axes and type

------------------------------------------------------------------------

### `Ggplot2RocLayerProcessor$as_rates()`

Hand the rates back as numbers, inverting `x` when asked

The line processor stringifies `x` on the way out, because a line's x
may be a date or a category. A rate is neither, and the core does
arithmetic on it.

#### Usage

    Ggplot2RocLayerProcessor$as_rates(data, inverted = FALSE)

#### Arguments

- `data`:

  The series list the line processor emitted

- `inverted`:

  Whether `x` is specificity, to be read as `1 - x`

#### Returns

The series list with numeric rates

------------------------------------------------------------------------

### `Ggplot2RocLayerProcessor$attach_thresholds()`

Attach each point's decision threshold, when the layer carries one

A `threshold` column survives the build only for a
[`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) layer, whose
geom names the aesthetic. The line processor drops the rows whose y is
`NA` and splits the rest by group in the group's own order, so the same
filter and split here put the thresholds back beside the points they
were scored at. A series whose count disagrees – a row the line
processor dropped for a reason other than `NA` y – gets no thresholds
rather than the wrong ones.

#### Usage

    Ggplot2RocLayerProcessor$attach_thresholds(data, built, panel_id = NULL)

#### Arguments

- `data`:

  The series list

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The series list, with `threshold` on each point that has one

------------------------------------------------------------------------

### `Ggplot2RocLayerProcessor$attach_areas()`

Attach the declared area to the first point of each curve

`maidr_roc(auc = )` names one area per curve. A named vector is matched
to the series by their names; an unnamed one is taken in series order
when it has one entry per series. Anything else is left out rather than
guessed, and the core measures the area from the points instead.

#### Usage

    Ggplot2RocLayerProcessor$attach_areas(data, layer)

#### Arguments

- `data`:

  The series list

- `layer`:

  The layer being read

#### Returns

The series list, with `auc` on each curve's first point

------------------------------------------------------------------------

### `Ggplot2RocLayerProcessor$rows_read()`

The built rows the line processor emitted points for

The same panel filter and `NA`-y filter `extract_data()` applies, so
that a column read off these rows lines up with the emitted points.

#### Usage

    Ggplot2RocLayerProcessor$rows_read(built, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The rows, or NULL when the layer built none

------------------------------------------------------------------------

### `Ggplot2RocLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2RocLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
