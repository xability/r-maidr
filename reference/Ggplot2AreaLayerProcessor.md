# ggplot2 Area Layer Processor

Processes
[`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
into MAIDR's `area`, `stacked_area` and `stacked_normalized_area`
layers.

Before this processor existed these layers fell through to
`Ggplot2UnknownLayerProcessor`, so an area chart carried no data at all.

### Why not read it as a line

In a stacked area chart the band's **top edge** is a cumulative total
while the band's **height** is the series' own value. A line layer
announces one number per point with nothing to say which of those two it
is, so the type exists to keep them apart: MAIDR's area trace announces
the series' value and reports the running total beside it.

### The two traps in ggplot2's built data

**`y` is not the value.** ggplot2 stacks by computing absolute band
edges, so `ymin`/`ymax` are the cumulative positions and `y` is the top
edge. The series' own value is `ymax - ymin`, and MAIDR sums the series
itself to reach the total. Emitting `y` would hand it a cumulative
number to accumulate again, announcing totals that grow with the number
of series rather than with the data.

**Most of the rows are not data.**
[`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
defaults to `stat = "align"`, which inserts interpolation vertices so
the bands stack cleanly and closes each polygon on the baseline. A
four-point, two-series chart produces twenty-four rows:

           x      y  ymin   ymax group align_padding
     1999.997  0.000 0.000  0.000     1          TRUE
     2000.000  5.000 2.000  5.000     1         FALSE
     2000.003  5.009 2.003  5.009     1         FALSE   <- not a data point
     2000.997  7.991 2.997  7.991     1         FALSE   <- not a data point

Read whole, a chart of four years announces twelve points per series,
including a reading of `5.009` at "year 2000.003" – a value the data
does not hold at an x the chart does not have. `align_padding` does
**not** identify them: it marks only the two baseline-closing vertices.

The rows that are data are those whose `x` the layer's own data carries,
which is verified to give the same answer as `stat = "identity"`.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\> `Ggplot2AreaLayerProcessor`

## Methods

### Public methods

- [`Ggplot2AreaLayerProcessor$process()`](#method-Ggplot2AreaLayerProcessor-process)

- [`Ggplot2AreaLayerProcessor$resolve_area_type()`](#method-Ggplot2AreaLayerProcessor-resolve_area_type)

- [`Ggplot2AreaLayerProcessor$extract_series()`](#method-Ggplot2AreaLayerProcessor-extract_series)

- [`Ggplot2AreaLayerProcessor$drop_alignment_vertices()`](#method-Ggplot2AreaLayerProcessor-drop_alignment_vertices)

- [`Ggplot2AreaLayerProcessor$source_x_values()`](#method-Ggplot2AreaLayerProcessor-source_x_values)

- [`Ggplot2AreaLayerProcessor$band_height()`](#method-Ggplot2AreaLayerProcessor-band_height)

- [`Ggplot2AreaLayerProcessor$resolve_series_labels()`](#method-Ggplot2AreaLayerProcessor-resolve_series_labels)

- [`Ggplot2AreaLayerProcessor$fill_levels()`](#method-Ggplot2AreaLayerProcessor-fill_levels)

- [`Ggplot2AreaLayerProcessor$attach_fill_axis()`](#method-Ggplot2AreaLayerProcessor-attach_fill_axis)

- [`Ggplot2AreaLayerProcessor$mapped_column()`](#method-Ggplot2AreaLayerProcessor-mapped_column)

- [`Ggplot2AreaLayerProcessor$scalar()`](#method-Ggplot2AreaLayerProcessor-scalar)

- [`Ggplot2AreaLayerProcessor$clone()`](#method-Ggplot2AreaLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`Ggplot2LineLayerProcessor$attach_discrete_y_names()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_discrete_y_names)
- [`Ggplot2LineLayerProcessor$attach_group_axis()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_group_axis)
- [`Ggplot2LineLayerProcessor$attach_level_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_level_labels)
- [`Ggplot2LineLayerProcessor$build_level_lookup()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-build_level_lookup)
- [`Ggplot2LineLayerProcessor$curve_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-curve_selectors)
- [`Ggplot2LineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_data)
- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_layer_axes)
- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_multiline_data)
- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_single_line_data)
- [`Ggplot2LineLayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_layer_polyline_grob)
- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_main_polyline_grob)
- [`Ggplot2LineLayerProcessor$format_x_value()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-format_x_value)
- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_multiline_selectors)
- [`Ggplot2LineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_selectors)
- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_single_line_selector)
- [`Ggplot2LineLayerProcessor$get_group_column()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_group_column)
- [`Ggplot2LineLayerProcessor$get_layer()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_layer)
- [`Ggplot2LineLayerProcessor$get_x_transformation()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_x_transformation)
- [`Ggplot2LineLayerProcessor$has_series_groups()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-has_series_groups)
- [`Ggplot2LineLayerProcessor$layer_polyline_grobs()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-layer_polyline_grobs)
- [`Ggplot2LineLayerProcessor$line_layer_position()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-line_layer_position)
- [`Ggplot2LineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-needs_reordering)
- [`Ggplot2LineLayerProcessor$normalize_point_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-normalize_point_values)
- [`Ggplot2LineLayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-other_geom_grob_prefixes)
- [`Ggplot2LineLayerProcessor$panel_axis_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-panel_axis_labels)
- [`Ggplot2LineLayerProcessor$polyline_curve_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-polyline_curve_count)
- [`Ggplot2LineLayerProcessor$recover_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-recover_x_values)
- [`Ggplot2LineLayerProcessor$resolve_group_mapping()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-resolve_group_mapping)
- [`Ggplot2LineLayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-resolve_panel_index)
- [`Ggplot2LineLayerProcessor$series_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-series_count)
- [`Ggplot2LineLayerProcessor$transform_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-transform_x_values)

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$process()`

Process the area layer.

#### Usage

    Ggplot2AreaLayerProcessor$process(
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

List with data, axes and type

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$resolve_area_type()`

Decide which of the three area types this layer is.

`position = "fill"` rescales every column to a common height, so a
band's height is its share of that column and every column totals 1 by
construction. Reading that as a plain stacked area would announce the
shares as if they were values and imply the columns have equal totals,
which is the one thing a filled chart is drawn to deny – the same
distinction `stacked_normalized_bar` draws for bars.

A single series has nothing stacked on it whatever its position, so it
is a plain area: announcing a running total equal to the value at every
point would be noise.

#### Usage

    Ggplot2AreaLayerProcessor$resolve_area_type(plot, series)

#### Arguments

- `plot`:

  The ggplot2 object

- `series`:

  The emitted series

#### Returns

One of "area", "stacked_area", "stacked_normalized_area"

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$extract_series()`

Build the MAIDR series for this layer.

Emits each series' **own** value rather than the cumulative band top,
because MAIDR's area trace sums the series to reach the running total
and announces the two separately.

#### Usage

    Ggplot2AreaLayerProcessor$extract_series(built, layer_data, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  This layer's computed rows

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of series, each a list of MAIDR points

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$drop_alignment_vertices()`

Keep only the rows the chart was given.

`StatAlign` inserts interpolation vertices and baseline-closing
vertices, neither of which is an observation. The rows that are data are
those whose `x` appears in the layer's own data; that filter is verified
to give the same rows `stat = "identity"` produces.

A layer whose x values cannot be recovered keeps every row rather than
losing the chart – a noisy reading being better than none – which is why
this returns the input unchanged rather than empty when the lookup
fails.

#### Usage

    Ggplot2AreaLayerProcessor$drop_alignment_vertices(built, layer_data)

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  This layer's computed rows

#### Returns

The data-bearing rows

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$source_x_values()`

Read the x values the layer was given, before any stat.

Reports a discrete axis as such rather than guessing its positions:
those are assigned by the scale, and reconstructing them from the data
column would drift the moment a factor level appeared in one and not the
other. The caller has an exact rule for that case.

"Discrete" and "could not be read" are answered differently, because the
caller must do different things with them. The integer rule that is
exact for a discrete axis would silently drop the fractional rows of a
continuous one, and an x mapped through an expression –
`aes(x = year / 2)`, say – resolves to no column and lands here while
still being continuous. Collapsing the two into one NULL is how that
axis loses half its data to a rule that was never about it.

#### Usage

    Ggplot2AreaLayerProcessor$source_x_values(built)

#### Arguments

- `built`:

  Built plot data

#### Returns

`list(kind = "discrete")`, `list(kind = "numeric", values =)`, or NULL
when the axis could not be read at all

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$band_height()`

The band's own height at one row.

Falls back to `y` when the edges are absent, since an unstacked layer
whose baseline is the axis draws a band of exactly that height.

#### Usage

    Ggplot2AreaLayerProcessor$band_height(rows, i)

#### Arguments

- `rows`:

  The rows of one series

- `i`:

  Which row

#### Returns

The series' value at that row

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$resolve_series_labels()`

Name each series after its fill level.

#### Usage

    Ggplot2AreaLayerProcessor$resolve_series_labels(built, rows, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `rows`:

  This layer's data-bearing rows

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A named list of group key to label

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$fill_levels()`

The fill levels, in the order ggplot2 numbered the groups.

#### Usage

    Ggplot2AreaLayerProcessor$fill_levels(built)

#### Arguments

- `built`:

  Built plot data

#### Returns

A character vector of levels, possibly empty

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$attach_fill_axis()`

Add the legend title as the z axis, when there is one.

#### Usage

    Ggplot2AreaLayerProcessor$attach_fill_axis(plot, built, axes, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `axes`:

  The axes assembled so far

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The axes, with `z` added when a fill legend exists

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$mapped_column()`

Name the source column an aesthetic is mapped to.

`aes(x = factor(year))` maps a call rather than a bare name, and the
column the data actually holds is its argument – so the call is
unwrapped rather than labelled, which would give `"factor(year)"` and
match nothing.

#### Usage

    Ggplot2AreaLayerProcessor$mapped_column(quo)

#### Arguments

- `quo`:

  The mapped quosure, or NULL

#### Returns

The column name, or NULL when there is no mapping

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$scalar()`

Convert one coordinate to a JSON-safe scalar.

#### Usage

    Ggplot2AreaLayerProcessor$scalar(value)

#### Arguments

- `value`:

  A coordinate read off the built data

#### Returns

A number, or a string when the coordinate is not numeric

------------------------------------------------------------------------

### `Ggplot2AreaLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2AreaLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
