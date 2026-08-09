# Final Line Layer Processor - Uses Actual SVG Structure

Processes line plot layers using the actual gridSVG structure
discovered:

- Lines: GRID.polyline.61.1.1, GRID.polyline.61.1.2,
  GRID.polyline.61.1.3

- Points: geom_point.points.63.1.1 through geom_point.points.63.1.24
  (grouped by series)

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2LineLayerProcessor`

## Public fields

- `layer_info`:

  Information about the layer being processed

- `last_result`:

  The last processing result

## Active bindings

- `layer_info`:

  Information about the layer being processed

- `last_result`:

  The last processing result

## Methods

### Public methods

- [`Ggplot2LineLayerProcessor$process()`](#method-Ggplot2LineLayerProcessor-process)

- [`Ggplot2LineLayerProcessor$attach_group_axis()`](#method-Ggplot2LineLayerProcessor-attach_group_axis)

- [`Ggplot2LineLayerProcessor$has_series_groups()`](#method-Ggplot2LineLayerProcessor-has_series_groups)

- [`Ggplot2LineLayerProcessor$resolve_group_mapping()`](#method-Ggplot2LineLayerProcessor-resolve_group_mapping)

- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](#method-Ggplot2LineLayerProcessor-extract_layer_axes)

- [`Ggplot2LineLayerProcessor$extract_data()`](#method-Ggplot2LineLayerProcessor-extract_data)

- [`Ggplot2LineLayerProcessor$resolve_panel_index()`](#method-Ggplot2LineLayerProcessor-resolve_panel_index)

- [`Ggplot2LineLayerProcessor$get_x_transformation()`](#method-Ggplot2LineLayerProcessor-get_x_transformation)

- [`Ggplot2LineLayerProcessor$transform_x_values()`](#method-Ggplot2LineLayerProcessor-transform_x_values)

- [`Ggplot2LineLayerProcessor$format_x_value()`](#method-Ggplot2LineLayerProcessor-format_x_value)

- [`Ggplot2LineLayerProcessor$get_original_x_column()`](#method-Ggplot2LineLayerProcessor-get_original_x_column)

- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](#method-Ggplot2LineLayerProcessor-extract_multiline_data)

- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](#method-Ggplot2LineLayerProcessor-extract_single_line_data)

- [`Ggplot2LineLayerProcessor$get_group_column()`](#method-Ggplot2LineLayerProcessor-get_group_column)

- [`Ggplot2LineLayerProcessor$generate_selectors()`](#method-Ggplot2LineLayerProcessor-generate_selectors)

- [`Ggplot2LineLayerProcessor$series_count()`](#method-Ggplot2LineLayerProcessor-series_count)

- [`Ggplot2LineLayerProcessor$curve_selectors()`](#method-Ggplot2LineLayerProcessor-curve_selectors)

- [`Ggplot2LineLayerProcessor$find_layer_polyline_grob()`](#method-Ggplot2LineLayerProcessor-find_layer_polyline_grob)

- [`Ggplot2LineLayerProcessor$layer_polyline_grobs()`](#method-Ggplot2LineLayerProcessor-layer_polyline_grobs)

- [`Ggplot2LineLayerProcessor$other_geom_grob_prefixes()`](#method-Ggplot2LineLayerProcessor-other_geom_grob_prefixes)

- [`Ggplot2LineLayerProcessor$polyline_curve_count()`](#method-Ggplot2LineLayerProcessor-polyline_curve_count)

- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](#method-Ggplot2LineLayerProcessor-generate_multiline_selectors)

- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](#method-Ggplot2LineLayerProcessor-generate_single_line_selector)

- [`Ggplot2LineLayerProcessor$line_layer_position()`](#method-Ggplot2LineLayerProcessor-line_layer_position)

- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](#method-Ggplot2LineLayerProcessor-find_main_polyline_grob)

- [`Ggplot2LineLayerProcessor$needs_reordering()`](#method-Ggplot2LineLayerProcessor-needs_reordering)

- [`Ggplot2LineLayerProcessor$clone()`](#method-Ggplot2LineLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

Process the line layer with actual SVG structure

#### Usage

    Ggplot2LineLayerProcessor$process(
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

#### Returns

List with data and selectors

------------------------------------------------------------------------

### Method `attach_group_axis()`

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

### Method `has_series_groups()`

Report whether extracted data is split into named series.

#### Usage

    Ggplot2LineLayerProcessor$has_series_groups(data)

#### Arguments

- `data`:

  The extracted layer data

#### Returns

TRUE when there is more than one series and points carry z

------------------------------------------------------------------------

### Method `resolve_group_mapping()`

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

### Method `extract_layer_axes()`

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

### Method `extract_data()`

Extract data from line layer (single or multiline)

#### Usage

    Ggplot2LineLayerProcessor$extract_data(
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

List of arrays, each containing series data points

------------------------------------------------------------------------

### Method `resolve_panel_index()`

Resolve which entry of `built$layout$panel_params` describes a facet
panel.

Panel parameters are stored in the row order of `built$layout$layout`,
so panel `n` is entry `n`. An unfaceted plot (or an unusable id)
resolves to the only panel there is.

#### Usage

    Ggplot2LineLayerProcessor$resolve_panel_index(built, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `panel_id`:

  Panel id for faceted plots (optional)

#### Returns

Integer index guaranteed to be in range

------------------------------------------------------------------------

### Method `get_x_transformation()`

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

### Method `transform_x_values()`

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

### Method `format_x_value()`

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

------------------------------------------------------------------------

### Method `get_original_x_column()`

Recover the original (untransformed) x column for a layer.

[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
transforms Date / POSIXct columns into numeric days-since-epoch on
`built$data[[i]]$x`. To emit ISO strings we need the original column
from `plot$data` (or the layer's own `data`).

Returns the per-row vector of x values aligned to `built_data` if a
simple column reference is found and the lengths match, otherwise NULL.

#### Usage

    Ggplot2LineLayerProcessor$get_original_x_column(plot, built_data)

------------------------------------------------------------------------

### Method `extract_multiline_data()`

Extract data for multiple line series

#### Usage

    Ggplot2LineLayerProcessor$extract_multiline_data(layer_data, plot)

#### Arguments

- `layer_data`:

  The built layer data

- `plot`:

  The original ggplot2 object

#### Returns

List of arrays, each containing series data

------------------------------------------------------------------------

### Method `extract_single_line_data()`

Extract data for single line (backward compatibility)

#### Usage

    Ggplot2LineLayerProcessor$extract_single_line_data(layer_data, plot = NULL)

#### Arguments

- `layer_data`:

  The built layer data

#### Returns

List containing single series data

------------------------------------------------------------------------

### Method `get_group_column()`

Get the grouping column name from plot mappings

#### Usage

    Ggplot2LineLayerProcessor$get_group_column(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Name of the grouping column

------------------------------------------------------------------------

### Method `generate_selectors()`

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

### Method `series_count()`

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

### Method `curve_selectors()`

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

### Method `find_layer_polyline_grob()`

The polyline grob ggplot2 drew for THIS line layer.

#### Usage

    Ggplot2LineLayerProcessor$find_layer_polyline_grob(plot, panel_grob)

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

#### Returns

The matching grob, or NULL

------------------------------------------------------------------------

### Method `layer_polyline_grobs()`

Panel polylines that a line layer could have drawn.

`GeomPath$draw_panel()` returns a bare `polylineGrob`, so a line layer's
grob carries grid's auto-generated `GRID.polyline.N` name with no geom
prefix to match on – only its draw-order position identifies it. Layers
that DO name their grob tree after their geom (`geom_smooth.gTree.N`)
are skipped whole via
[`geom_grob_prefix()`](https://r.maidr.ai/reference/geom_grob_prefix.md),
the same helper the smooth processor uses to scope itself to its own
tree; without that, the smooth's three curves are counted as line-layer
polylines and shift every position by three. Panel grid lines are named
after the theme element (`panel.grid.major.x..polyline.N`) and so never
match.

#### Usage

    Ggplot2LineLayerProcessor$layer_polyline_grobs(plot, panel_grob)

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

#### Returns

List of grobs in draw order

------------------------------------------------------------------------

### Method `other_geom_grob_prefixes()`

Grob-name prefixes belonging to the plot's OTHER geoms.

This layer's own prefix is excluded so that a second layer sharing the
geom (two
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
calls) is still walked.

#### Usage

    Ggplot2LineLayerProcessor$other_geom_grob_prefixes(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Character vector of prefixes, possibly empty

------------------------------------------------------------------------

### Method `polyline_curve_count()`

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

### Method `generate_multiline_selectors()`

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

### Method `generate_single_line_selector()`

Generate selector for single line plot

#### Usage

    Ggplot2LineLayerProcessor$generate_single_line_selector(base_id)

#### Arguments

- `base_id`:

  The base ID from the grob

#### Returns

List with single selector

------------------------------------------------------------------------

### Method `line_layer_position()`

Position (1-based) of this layer among line-typed layers in `plot`.
Returns NULL if the registry-based detection fails.

#### Usage

    Ggplot2LineLayerProcessor$line_layer_position(plot)

------------------------------------------------------------------------

### Method `find_main_polyline_grob()`

Find the main polyline grob (GRID.polyline.XX)

#### Usage

    Ggplot2LineLayerProcessor$find_main_polyline_grob(gt)

#### Arguments

- `gt`:

  The gtable to search

#### Returns

The main polyline grob or NULL

------------------------------------------------------------------------

### Method `needs_reordering()`

Check if layer needs reordering

#### Usage

    Ggplot2LineLayerProcessor$needs_reordering()

#### Returns

FALSE (line plots typically don't need reordering)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2LineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
