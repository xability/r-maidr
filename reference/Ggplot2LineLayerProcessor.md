# Final Line Layer Processor - Uses Actual SVG Structure

Processes line plot layers using the actual gridSVG structure
discovered:

- Lines: GRID.polyline.61.1.1, GRID.polyline.61.1.2,
  GRID.polyline.61.1.3

- Points: geom_point.points.63.1.1 through geom_point.points.63.1.24
  (grouped by series)

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2LineLayerProcessor`

## Methods

### Public methods

- [`Ggplot2LineLayerProcessor$process()`](#method-Ggplot2LineLayerProcessor-process)

- [`Ggplot2LineLayerProcessor$attach_group_axis()`](#method-Ggplot2LineLayerProcessor-attach_group_axis)

- [`Ggplot2LineLayerProcessor$has_series_groups()`](#method-Ggplot2LineLayerProcessor-has_series_groups)

- [`Ggplot2LineLayerProcessor$resolve_group_mapping()`](#method-Ggplot2LineLayerProcessor-resolve_group_mapping)

- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](#method-Ggplot2LineLayerProcessor-extract_layer_axes)

- [`Ggplot2LineLayerProcessor$extract_data()`](#method-Ggplot2LineLayerProcessor-extract_data)

- [`Ggplot2LineLayerProcessor$attach_discrete_y_names()`](#method-Ggplot2LineLayerProcessor-attach_discrete_y_names)

- [`Ggplot2LineLayerProcessor$normalize_point_values()`](#method-Ggplot2LineLayerProcessor-normalize_point_values)

- [`Ggplot2LineLayerProcessor$panel_axis_labels()`](#method-Ggplot2LineLayerProcessor-panel_axis_labels)

- [`Ggplot2LineLayerProcessor$build_level_lookup()`](#method-Ggplot2LineLayerProcessor-build_level_lookup)

- [`Ggplot2LineLayerProcessor$attach_level_labels()`](#method-Ggplot2LineLayerProcessor-attach_level_labels)

- [`Ggplot2LineLayerProcessor$get_layer()`](#method-Ggplot2LineLayerProcessor-get_layer)

- [`Ggplot2LineLayerProcessor$get_x_transformation()`](#method-Ggplot2LineLayerProcessor-get_x_transformation)

- [`Ggplot2LineLayerProcessor$transform_x_values()`](#method-Ggplot2LineLayerProcessor-transform_x_values)

- [`Ggplot2LineLayerProcessor$format_x_value()`](#method-Ggplot2LineLayerProcessor-format_x_value)

- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](#method-Ggplot2LineLayerProcessor-extract_multiline_data)

- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](#method-Ggplot2LineLayerProcessor-extract_single_line_data)

- [`Ggplot2LineLayerProcessor$recover_x_values()`](#method-Ggplot2LineLayerProcessor-recover_x_values)

- [`Ggplot2LineLayerProcessor$get_group_column()`](#method-Ggplot2LineLayerProcessor-get_group_column)

- [`Ggplot2LineLayerProcessor$generate_selectors()`](#method-Ggplot2LineLayerProcessor-generate_selectors)

- [`Ggplot2LineLayerProcessor$series_count()`](#method-Ggplot2LineLayerProcessor-series_count)

- [`Ggplot2LineLayerProcessor$curve_selectors()`](#method-Ggplot2LineLayerProcessor-curve_selectors)

- [`Ggplot2LineLayerProcessor$polyline_curve_count()`](#method-Ggplot2LineLayerProcessor-polyline_curve_count)

- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](#method-Ggplot2LineLayerProcessor-generate_multiline_selectors)

- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](#method-Ggplot2LineLayerProcessor-generate_single_line_selector)

- [`Ggplot2LineLayerProcessor$line_layer_position()`](#method-Ggplot2LineLayerProcessor-line_layer_position)

- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](#method-Ggplot2LineLayerProcessor-find_main_polyline_grob)

- [`Ggplot2LineLayerProcessor$needs_reordering()`](#method-Ggplot2LineLayerProcessor-needs_reordering)

- [`Ggplot2LineLayerProcessor$clone()`](#method-Ggplot2LineLayerProcessor-clone)

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

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$process()`

Process the line layer with actual SVG structure

#### Usage

    Ggplot2LineLayerProcessor$process(
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

  Panel context for panel-scoped selector generation (optional)

#### Returns

List with data and selectors

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$attach_group_axis()`

Add the legend title as the z axis label for a multi-series line layer.

Shared with the smooth layer processor via
[`attach_series_group_axis()`](https://r.maidr.ai/reference/attach_series_group_axis.md);
see `R/series_group_utils.R`.

#### Usage

    Ggplot2LineLayerProcessor$attach_group_axis(plot, built, data, axes)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `data`:

  The extracted layer data

- `axes`:

  Axes built so far

#### Returns

The axes list, with z added when the layer is grouped

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$has_series_groups()`

Report whether extracted data is split into named series.

#### Usage

    Ggplot2LineLayerProcessor$has_series_groups(data)

#### Arguments

- `data`:

  The extracted layer data

#### Returns

TRUE when there is more than one series and points carry z

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$resolve_group_mapping()`

Resolve the aesthetic that splits this layer into series.

A line has no fill, so only the colour aesthetic is probed.

#### Usage

    Ggplot2LineLayerProcessor$resolve_group_mapping(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

list with `aes` (aesthetic spelling variants, or NULL when nothing is
mapped) and `column` (the mapped column name, or "group" as a fallback)

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$extract_layer_axes()`

Extract axes labels for line layers, with a special case for
moving-average geoms (e.g.
[`tidyquant::geom_ma`](https://business-science.github.io/tidyquant/reference/geom_ma.html)).

By default the parent `LayerProcessor$extract_layer_axes()` reads the
y-label from the layer's aesthetic mapping. For a moving-average overlay
typically written as `geom_ma(aes(y = close), ma_fun = SMA, ...)`, this
yields the literal input-column name `"close"`, which is misleading: the
value being plotted (and announced during navigation) is the moving
average of `close`, not `close` itself. We detect `GeomMA` (the class of
tidyquant's geom_ma layer) and override the y-label accordingly. Plain
`geom_line` / `geom_smooth` overlays are untouched.

#### Usage

    Ggplot2LineLayerProcessor$extract_layer_axes(plot, layout)

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

#### Returns

list(x = list(label = ...), y = list(label = ...))

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$extract_data()`

Extract data from line layer (single or multiline)

#### Usage

    Ggplot2LineLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List of arrays, each containing series data points

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$attach_discrete_y_names()`

Give every point the *name* of its discrete y level.

A factor y aesthetic reaches the payload as ggplot2's internal level
code, so without this a reader hears "5" where the axis says "Awake".
`y` deliberately stays numeric – it drives sonification, braille and the
min/max range – and the name rides alongside as `label`.

A continuous y is returned untouched, so no `label` is emitted and the
frontend announces the number, which is the right reading there.

#### Usage

    Ggplot2LineLayerProcessor$attach_discrete_y_names(
      series_data,
      plot,
      built,
      panel_id = NULL
    )

#### Arguments

- `series_data`:

  List of series produced by the extractors above

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The series list, labelled when y is discrete

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$normalize_point_values()`

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

    Ggplot2LineLayerProcessor$normalize_point_values(series_data)

#### Arguments

- `series_data`:

  List of series produced by the line extractor

#### Returns

The series list with numeric y values

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$panel_axis_labels()`

Read one panel's own axis labels.

The labels ggplot2 drew on a panel's axis, which is what a sighted
reader sees, and which both discrete recoveries below start from: the y
level names in `build_level_lookup()`, and the x values in
`recover_x_values()`. Both need the same three things to hold before the
labels can be trusted – present, non-empty, no `NA` – so the check lives
here rather than being spelled out at each call site.

The `tryCatch` is not incidental: `get_labels()` is one of the accessors
whose spelling has moved between ggplot2 versions, the same reason
`get_x_transformation()` exists. Guarding it in one place leaves the
next version bump one site to fix instead of two that can drift.

Indexes with `[[axis]]` rather than `$x` / `$y`: `$` on a list falls
back to partial matching, so a `panel_params` without an `x` but with an
`x.range` would silently hand back the range. Exact matching returns
NULL there, which is the honest answer.

#### Usage

    Ggplot2LineLayerProcessor$panel_axis_labels(built, panel_index, axis)

#### Arguments

- `built`:

  Built plot data

- `panel_index`:

  Index into `built$layout$panel_params`

- `axis`:

  Either `"x"` or `"y"`

#### Returns

Character vector of labels, or NULL when the panel has no such scale or
its labels are unusable

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$build_level_lookup()`

Build a numeric-level to level-name lookup for the y aesthetic.

For a factor (or character) y aesthetic,
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
replaces the level with its numeric position, so `built$data$y` is a
level *code* and the name has to be recovered from somewhere else.

It is recovered from the panel's own y scale – the very labels ggplot2
draws on the axis – which makes the announcement agree with what a
sighted reader sees, and sidesteps two traps:

- **Row order is not a join key.** `GeomLine$setup_data()` sorts the
  built data by (PANEL, group, x) – that sort is the documented
  difference between
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  and
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  – while the caller's column keeps its own order, so pairing them row
  by row attaches the wrong name to the wrong code.

- **Unused levels are dropped.** A discrete scale defaults to
  `drop = TRUE`, so a factor declaring five levels of which two are
  drawn is coded 1..2, not by position in
  [`levels()`](https://rdrr.io/r/base/levels.html). Reading names off
  the factor would name code 2 after the second declared level rather
  than the second drawn one.

Returns NULL for a plain continuous y, in which case no `label` is
emitted and the frontend announces the numeric value.

#### Usage

    Ggplot2LineLayerProcessor$build_level_lookup(plot, built, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object (unused; kept for call-site symmetry)

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional) – each panel carries its own
  scale under `scales = "free_y"`

#### Returns

Named character vector keyed by the built y value, or NULL

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$attach_level_labels()`

Attach the ordinal level name to every point of every series. Points
whose y has no entry in the lookup are left untouched, so the frontend
falls back to the numeric announcement for them.

#### Usage

    Ggplot2LineLayerProcessor$attach_level_labels(series_data, lookup)

#### Arguments

- `series_data`:

  List of series produced by the line extractor

- `lookup`:

  Named character vector keyed by the built y value

#### Returns

The series list with `label` attached where known

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$get_layer()`

The ggplot2 layer this processor is responsible for.

#### Usage

    Ggplot2LineLayerProcessor$get_layer(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

The layer, or NULL when the index does not resolve

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$get_x_transformation()`

The transformation a panel's x scale applies to positions.

[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
stores x positions in transformed space, so under
[`scale_x_log10()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)
the data value 100 is recorded as 2. Recovering the value the axis
actually shows needs the scale's own transformation. ggplot2 \>= 3.5
exposes it through `get_transformation()`; earlier versions keep it in
the scale's `trans` field.

#### Usage

    Ggplot2LineLayerProcessor$get_x_transformation(built, panel_index)

#### Arguments

- `built`:

  Built plot data

- `panel_index`:

  Index into `built$layout$panel_params`

#### Returns

A scales transform object, or NULL when none is available

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$transform_x_values()`

Project raw x values into the space
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
stores positions in.

Going forwards (raw -\> transformed) rather than inverting the built
positions keeps the comparison exact: it repeats the very computation
ggplot2 performed, so no floating-point drift is introduced. Values the
transformation cannot represent (a non-positive number under a log
scale, say) become NA and simply fail to match.

#### Usage

    Ggplot2LineLayerProcessor$transform_x_values(values, transformation)

#### Arguments

- `values`:

  Raw values taken from the plot's data

- `transformation`:

  Transform object from `get_x_transformation()`, or NULL

#### Returns

Numeric vector the same length as `values`

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$format_x_value()`

Format an x-axis value as character.

Date / POSIXct / POSIXlt values are formatted via
[`format()`](https://rdrr.io/r/base/format.html) so that a `Date` column
emits ISO date strings (e.g. "2024-01-02") rather than the underlying
numeric days-since-epoch representation produced by
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html).
All other types use
[`as.character()`](https://rdrr.io/r/base/character.html). Mirrors
`Ggplot2BarLayerProcessor$format_x_value()` so bar and line layers from
the same Date column align string-wise.

#### Usage

    Ggplot2LineLayerProcessor$format_x_value(x)

#### Arguments

- `x`:

  The value to format

#### Returns

Character vector

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$extract_multiline_data()`

Extract data for multiple line series

#### Usage

    Ggplot2LineLayerProcessor$extract_multiline_data(
      layer_data,
      plot,
      recovered_x = NULL
    )

#### Arguments

- `layer_data`:

  The built layer data

- `plot`:

  The original ggplot2 object

- `recovered_x`:

  x values recovered from the built column by `recover_x_values()`,
  aligned to `layer_data`'s rows. NULL leaves the built value in place.

#### Returns

List of arrays, each containing series data

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$extract_single_line_data()`

Extract data for single line (backward compatibility)

#### Usage

    Ggplot2LineLayerProcessor$extract_single_line_data(
      layer_data,
      plot = NULL,
      recovered_x = NULL
    )

#### Arguments

- `layer_data`:

  The built layer data

- `plot`:

  The original ggplot2 object. Unread since x recovery moved upstream;
  kept for signature parity with `extract_multiline_data()` and for
  existing call sites.

- `recovered_x`:

  x values recovered from the built column by `recover_x_values()`,
  aligned to `layer_data`'s rows. NULL leaves the built value in place.

#### Returns

List containing single series data

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$recover_x_values()`

The x values to announce, recovered from the BUILT column.

[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
stores x in the scale's own space – a level code for a discrete scale,
days-since-epoch for a Date – so something has to turn it back into what
the axis shows. The obvious route, reading the caller's column, cannot
be indexed by the built row number: `GeomLine$setup_data()` sorts the
built data by (PANEL, group, x), which is the documented difference
between
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
and
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html),
while the caller's column keeps its own order. Pairing the two by
position hands every point another point's x.

Recovering from the built value instead is order-proof by construction,
and per scale type it needs:

- discrete – the panel's own x labels, indexed by the level code, the
  same source `build_level_lookup()` uses for a discrete y

- transformed (Date, POSIXct, log) – the transformation's inverse

- plain numeric – nothing; the built value already IS the value

#### Usage

    Ggplot2LineLayerProcessor$recover_x_values(layer_data, built, panel_id = NULL)

#### Arguments

- `layer_data`:

  The built layer data for this layer

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A vector aligned to `layer_data`'s rows, or NULL to leave the built
value alone

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$get_group_column()`

Get the grouping column name from plot mappings

#### Usage

    Ggplot2LineLayerProcessor$get_group_column(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Name of the grouping column

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$generate_selectors()`

One selector per series this line layer draws.

The panel-wide polyline list conflates two different things: a grouped
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
draws ALL of its curves as ONE `polylineGrob` whose `id` splits it
(gridSVG then emits `GRID.polyline.N.1.1`, `.1.2`, ... per curve), while
a second polyline-producing layer such as
[`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
adds further grobs of its own. Indexing that flat list by this layer's
position among line layers therefore returned one selector for a
three-curve layer as soon as a smooth sat beside it, and the frontend's
multiline trace refuses a selector list whose length does not equal the
series count – so the layer lost highlighting entirely rather than
mis-aiming it.

This resolves THIS layer's own grob first and then enumerates the curves
inside it, emitting one selector per curve. When the curves cannot be
lined up with the series, no selector is emitted: a caller can tell an
absent selector apart from a wrong one, a user cannot.

#### Usage

    Ggplot2LineLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL,
      built = NULL,
      n_series = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation

- `built`:

  Built plot data (optional)

- `n_series`:

  Number of series `extract_data()` produced, or NULL to derive it from
  the built layer data

#### Returns

List of selectors for each series

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$series_count()`

Number of series this layer draws in the given panel.

Never throws: selector generation has to degrade gracefully for inputs
`extract_data()` would reject.

#### Usage

    Ggplot2LineLayerProcessor$series_count(plot, built = NULL, panel_ctx = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation

#### Returns

Number of series, at least 1

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$curve_selectors()`

Selectors for the curves inside this layer's own grob.

#### Usage

    Ggplot2LineLayerProcessor$curve_selectors(plot, panel_grob, n_series)

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

- `n_series`:

  Number of series the layer produced

#### Returns

List of selectors, or NULL when the grob does not line up with the
series

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$polyline_curve_count()`

Number of separate curves a polyline grob draws.

`polylineGrob()` splits one grob into several drawn lines via `id` /
`id.lengths`; gridSVG renders each as its own SVG element suffixed
`.1.<k>`.

#### Usage

    Ggplot2LineLayerProcessor$polyline_curve_count(grob)

#### Arguments

- `grob`:

  A polyline grob

#### Returns

Integer count, at least 1

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$generate_multiline_selectors()`

Generate selectors for multiline plots using actual structure

#### Usage

    Ggplot2LineLayerProcessor$generate_multiline_selectors(base_id, num_series)

#### Arguments

- `base_id`:

  The base ID from the grob (e.g., "61")

- `num_series`:

  Number of series

#### Returns

List of selectors

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$generate_single_line_selector()`

Generate selector for single line plot

#### Usage

    Ggplot2LineLayerProcessor$generate_single_line_selector(base_id)

#### Arguments

- `base_id`:

  The base ID from the grob

#### Returns

List with single selector

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$line_layer_position()`

Position of this layer among the polyline-producing layers.

Delegates to
[`polyline_layer_position()`](https://r.maidr.ai/reference/polyline_layer_position.md),
which counts every layer type that renders an auto-named polyline:
"line", "step" and "contour". `layer_polyline_grobs()` skips only the
layers that name their grob tree after their geom, and none of these
three do. `GeomContour` defines no `draw_panel()` of its own and so
draws through `GeomPath`'s – a bare `polylineGrob` – while `GeomStep`
stairsteps its data and then calls the same method; either sits in that
candidate list exactly as a
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
does. Counting only "line" layers would therefore index the wrong
polyline for *every* layer of a plot that combines them.

#### Usage

    Ggplot2LineLayerProcessor$line_layer_position(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

The 1-based position, or NULL if registry-based detection fails

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$find_main_polyline_grob()`

Find the main polyline grob (GRID.polyline.XX)

#### Usage

    Ggplot2LineLayerProcessor$find_main_polyline_grob(gt)

#### Arguments

- `gt`:

  The gtable to search

#### Returns

The main polyline grob or NULL

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$needs_reordering()`

Check if layer needs reordering

#### Usage

    Ggplot2LineLayerProcessor$needs_reordering()

#### Returns

FALSE (line plots typically don't need reordering)

------------------------------------------------------------------------

### `Ggplot2LineLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2LineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
