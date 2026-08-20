# ggplot2 Error Bar Layer Processor

Processes ggplot2's uncertainty geoms –
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
[`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
[`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
and
[`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
– into MAIDR's `error_bar` layer.

Uncertainty is usually the finding rather than the decoration: whether
two group means differ is answered by whether their intervals overlap.
Until this processor existed every one of these geoms fell through to
`Ggplot2UnknownLayerProcessor`, so the interval was dropped and that
comparison was unavailable to a MAIDR reader.

### Reading the right pair of bounds

The trap this class exists to avoid is that ggplot2's built data carries
**both** pairs for most of these geoms, and only one of them is the
interval. A vertical
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
computes:

      x  y  ymin ymax  xmin  xmax  flipped_aes
      1 4.2  3.8  4.6  0.55  1.45  FALSE

`ymin`/`ymax` are the interval; `xmin`/`xmax` are the *cap width* – how
wide the little crossbars are drawn, which is a styling parameter and
not data at all. Reading the wrong pair yields a chart describing the
cap geometry, which is both wrong and plausible-looking.

Which pair is the interval is decided by the layer's orientation, and
ggplot2 records that in two different ways depending on the geom:

- `geom_errorbar(orientation = "y")` and friends set a `flipped_aes`
  column to `TRUE` in the built data.

- [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  has no `flipped_aes` column at all – it is horizontal by construction.

Both are handled, because a layer that read only `flipped_aes` would
treat every
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
as vertical and emit the cap heights as the interval.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2PointLayerProcessor`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.md)
-\> `Ggplot2ErrorbarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2ErrorbarLayerProcessor$process()`](#method-Ggplot2ErrorbarLayerProcessor-process)

- [`Ggplot2ErrorbarLayerProcessor$attach_group_axis()`](#method-Ggplot2ErrorbarLayerProcessor-attach_group_axis)

- [`Ggplot2ErrorbarLayerProcessor$resolve_interval_groups()`](#method-Ggplot2ErrorbarLayerProcessor-resolve_interval_groups)

- [`Ggplot2ErrorbarLayerProcessor$group_values_agree()`](#method-Ggplot2ErrorbarLayerProcessor-group_values_agree)

- [`Ggplot2ErrorbarLayerProcessor$layer_built_rows()`](#method-Ggplot2ErrorbarLayerProcessor-layer_built_rows)

- [`Ggplot2ErrorbarLayerProcessor$panel_row_indices()`](#method-Ggplot2ErrorbarLayerProcessor-panel_row_indices)

- [`Ggplot2ErrorbarLayerProcessor$interval_group_frame()`](#method-Ggplot2ErrorbarLayerProcessor-interval_group_frame)

- [`Ggplot2ErrorbarLayerProcessor$is_horizontal_layer()`](#method-Ggplot2ErrorbarLayerProcessor-is_horizontal_layer)

- [`Ggplot2ErrorbarLayerProcessor$draws_one_shape_for_every_sample()`](#method-Ggplot2ErrorbarLayerProcessor-draws_one_shape_for_every_sample)

- [`Ggplot2ErrorbarLayerProcessor$generate_selectors()`](#method-Ggplot2ErrorbarLayerProcessor-generate_selectors)

- [`Ggplot2ErrorbarLayerProcessor$interval_sample_selectors()`](#method-Ggplot2ErrorbarLayerProcessor-interval_sample_selectors)

- [`Ggplot2ErrorbarLayerProcessor$find_interval_grob()`](#method-Ggplot2ErrorbarLayerProcessor-find_interval_grob)

- [`Ggplot2ErrorbarLayerProcessor$find_unnamed_interval_grob()`](#method-Ggplot2ErrorbarLayerProcessor-find_unnamed_interval_grob)

- [`Ggplot2ErrorbarLayerProcessor$interval_grob_shape()`](#method-Ggplot2ErrorbarLayerProcessor-interval_grob_shape)

- [`Ggplot2ErrorbarLayerProcessor$grob_point_groups()`](#method-Ggplot2ErrorbarLayerProcessor-grob_point_groups)

- [`Ggplot2ErrorbarLayerProcessor$drawn_run_count()`](#method-Ggplot2ErrorbarLayerProcessor-drawn_run_count)

- [`Ggplot2ErrorbarLayerProcessor$interval_selector()`](#method-Ggplot2ErrorbarLayerProcessor-interval_selector)

- [`Ggplot2ErrorbarLayerProcessor$extract_interval_data()`](#method-Ggplot2ErrorbarLayerProcessor-extract_interval_data)

- [`Ggplot2ErrorbarLayerProcessor$resolve_estimates()`](#method-Ggplot2ErrorbarLayerProcessor-resolve_estimates)

- [`Ggplot2ErrorbarLayerProcessor$resolve_category_labels()`](#method-Ggplot2ErrorbarLayerProcessor-resolve_category_labels)

- [`Ggplot2ErrorbarLayerProcessor$category_axis_labels()`](#method-Ggplot2ErrorbarLayerProcessor-category_axis_labels)

- [`Ggplot2ErrorbarLayerProcessor$clone()`](#method-Ggplot2ErrorbarLayerProcessor-clone)

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)
- [`Ggplot2PointLayerProcessor$extract_axes_labels()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axes_labels)
- [`Ggplot2PointLayerProcessor$extract_axis_grid_info()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axis_grid_info)
- [`Ggplot2PointLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_data)
- [`Ggplot2PointLayerProcessor$find_children_by_type()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_children_by_type)
- [`Ggplot2PointLayerProcessor$find_panel_grob()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_panel_grob)

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$process()`

Process the error bar layer.

#### Usage

    Ggplot2ErrorbarLayerProcessor$process(
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

List with data, selectors, axes, type and orientation

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$attach_group_axis()`

Name the series axis after the legend the chart shows.

Guarded on the split rather than on the payload's shape, because
[`data_has_series_groups()`](https://r.maidr.ai/reference/data_has_series_groups.md)
reads `data[[1]][[1]]$z` and an ungrouped layer's `data[[1]]` is a
point, whose first element is an atomic category name. The grouped shape
is the only one that has a z axis to name, so asking the split is both
safer and the actual question.

#### Usage

    Ggplot2ErrorbarLayerProcessor$attach_group_axis(
      plot,
      built,
      data,
      groups,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `data`:

  The extracted layer data

- `groups`:

  The layer's series split, or NULL

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The axes list, with z added when the layer is grouped

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$resolve_interval_groups()`

Split the layer's rows into the series the chart draws.

A dodged interval chart puts one whip per group at every category, and
without the split every category is announced twice with nothing saying
which reading belongs to which group – so the comparison the figure
exists to support, whether two groups' intervals overlap, is the one
thing unavailable (#183). MAIDR's grammar gained the grouped shape,
`ErrorBarPoint[][]` with a `z` per point, in xability/maidr#942.

The group each row belongs to cannot be read out of the built data:
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
replaces the grouping column with an integer `group` id, and on a
discrete x that id is the *interaction* of x and the grouping aesthetic
– 6 ids for 3 categories and 2 groups, measured – so it names a cell
rather than a series. The aesthetic's own values are replaced too, by
the palette colour they mapped to. The user's frame is what still holds
the names, and it is only usable while it still has a row per built row:
ggplot2 drops rows it cannot draw, and a padded lookup would name every
series `NA`. The same guard `Ggplot2StackedBarProcessor` applies for the
same reason.

A layer with its own `data` is read from that frame rather than the
plot's, matching ggplot2's own precedence.

#### Usage

    Ggplot2ErrorbarLayerProcessor$resolve_interval_groups(
      plot,
      layer_data,
      built,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `layer_data`:

  This layer's computed rows

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of `positions` (each row's series, as an index into `levels`),
`levels` (the series, in the order ggplot2 draws them) and `order` (the
row indices in series order), or NULL when the layer draws a single
undivided series

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$group_values_agree()`

Check the frame's values against what the layer drew.

Row counts agreeing is not the same as rows corresponding. A stat that
happens to emit as many rows as the frame has would pass the count test
while pairing a reading with somebody else's group name – the worst
failure available here, since every value stays correct and only the
label is a lie.

What can be checked is that the pairing is *consistent*: ggplot2 keeps
the grouping aesthetic in the built data as the value it mapped to (a
palette colour, a linetype), and a correct pairing gives every row
sharing that drawn value the same name. A shuffled one almost never
does. Falls back to the built `group` id when the aesthetic itself is
not in the built data, which is what an explicit `aes(group = ...)`
leaves behind.

#### Usage

    Ggplot2ErrorbarLayerProcessor$group_values_agree(layer_data, aes_names, values)

#### Arguments

- `layer_data`:

  This layer's computed rows

- `aes_names`:

  The winning aesthetic's spelling variants

- `values`:

  The frame's grouping values, one per row

#### Returns

TRUE when every drawn value carries a single name

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$layer_built_rows()`

This layer's built rows, every panel of them.

#### Usage

    Ggplot2ErrorbarLayerProcessor$layer_built_rows(built)

#### Arguments

- `built`:

  Built plot data

#### Returns

A data frame, or NULL when the layer index does not resolve

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$panel_row_indices()`

Which of the layer's built rows this panel's rows are.

Mirrors `get_layer_built_data()`, including its fallback: a panel id
that selects nothing leaves the whole layer in place, so the indices
have to as well. Answers NULL when the two do not line up, which is the
signal to decline the split rather than pair rows at random.

#### Usage

    Ggplot2ErrorbarLayerProcessor$panel_row_indices(full, rows, panel_id = NULL)

#### Arguments

- `full`:

  The layer's built rows, every panel of them

- `rows`:

  How many rows this panel contributed

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

Integer indices into `full`, or NULL

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$interval_group_frame()`

The frame still carrying the grouping column's own values.

#### Usage

    Ggplot2ErrorbarLayerProcessor$interval_group_frame(plot, rows)

#### Arguments

- `plot`:

  The ggplot2 object

- `rows`:

  How many rows the layer computed

#### Returns

A data frame with one row per built row, or NULL

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$is_horizontal_layer()`

Decide whether the interval runs along x rather than y.

Reads `flipped_aes` when the built data carries it, and falls back to
the geom class for
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
which is horizontal by construction and therefore has no such column to
read.

#### Usage

    Ggplot2ErrorbarLayerProcessor$is_horizontal_layer(plot, layer_data)

#### Arguments

- `plot`:

  The ggplot2 object

- `layer_data`:

  This layer's computed rows

#### Returns

TRUE when the interval spans the x axis

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$draws_one_shape_for_every_sample()`

Whether this layer draws its whole interval as one shape.

True for a ribbon, which fills a single polygon across every x. Every
other geom this processor serves draws one shape per sample – a
`segments` grob per
[`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
row, a polygon per
[`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
box – which is what makes a per-sample selector possible at all.

`class(...)[1]`, matching the adapter's own ribbon test: `GeomArea`
inherits `GeomRibbon` and is not routed here, but an
[`inherits()`](https://rdrr.io/r/base/class.html) check would still be
the wrong shape of question to ask.

#### Usage

    Ggplot2ErrorbarLayerProcessor$draws_one_shape_for_every_sample(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

TRUE when the layer's interval is one undivided shape

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$generate_selectors()`

Address the drawn interval, one SVG element per sample.

`ErrorBarTrace.mapToSvgElements` resolves the selectors and requires the
flattened result to be exactly as long as the emitted data; any other
length is discarded and the layer highlights nothing (#145). So the job
here is one element per sample, in the order the data was emitted – not
one per bound, and not the container.

The five geoms do not draw alike, and the differences are not cosmetic.
Verified against real
[`gridSVG::grid.export()`](https://rdrr.io/pkg/gridSVG/man/grid.export.html)
output on ggplot2 3.4.4:

- [`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  – a `segments` grob named after the geom; one `<polyline>` per sample.

- [`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  – a gTree holding that same `segments` grob and a `points` grob. The
  whisker is the one that spans the interval, so it is the one
  addressed.

- [`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  – a gTree holding a `polygon` grob (the box) and a `segments` grob
  (the middle line). The box is the sample.

- [`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  /
  [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  – **an unnamed `polyline`**, `GRID.polyline.N`, carrying no geom
  prefix at all, and drawing *three* elements per sample: a cap, the
  whisker, the other cap.

Both of those last two facts are why this could not reuse the inherited
`generate_selectors()`: it matches `geom_point.points` by name, which
reaches none of these, and a name-prefix search reaches
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
least of all.

#### Usage

    Ggplot2ErrorbarLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL,
      sample_count = NULL,
      order = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (unused; the drawn grob is resolved from the
  panel, which is what the unnamed polyline needs)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional) A grouped layer
  needs one selector per sample instead of one stride over all of them,
  because MAIDR flattens its series before pairing them against the
  resolved elements: the payload runs series by series while the chart
  draws row by row, and one stride can only ever produce the drawn
  order. The per-sample form addresses each mark by the **id** gridSVG
  gave it, not by position, so resolving one cannot disturb the rest – a
  positional list would, since resolving a selector inserts a hidden
  clone beside the match and shifts every later `nth-child`
  (xability/maidr#1004).

- `sample_count`:

  How many points this layer emitted

- `order`:

  The row indices in series order, or NULL when the layer draws a single
  undivided series

#### Returns

A list of CSS selectors, or an empty list

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$interval_sample_selectors()`

Address one drawn mark per sample, in series order.

gridSVG gives every exported element its own id, built from the grob's
name: `<grob>.1.<i>` where a sample is drawn as one element, and
`<grob>.1.<i>a`, `<i>b`, `<i>c` where
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
draws its cap, whisker and other cap. Measured on ggplot2 3.4.4 across
all four geoms this processor serves. The whisker is the middle one,
which is the same element the stride form's `nth-child(3n+2)` picks – so
a grouped chart and an ungrouped one outline the same mark.

Restricted to the two shapes `interval_selector()` handles, for the same
reason: an unverified element count would name a mark by an id pattern
nothing has been checked against.

#### Usage

    Ggplot2ErrorbarLayerProcessor$interval_sample_selectors(
      grob_name,
      per_sample,
      order
    )

#### Arguments

- `grob_name`:

  Name of the grob whose children are the samples

- `per_sample`:

  How many elements the grob draws per sample

- `order`:

  The row indices in series order

#### Returns

A list of CSS selectors, one per sample, or an empty list

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$find_interval_grob()`

Find the grob whose children are the samples.

#### Usage

    Ggplot2ErrorbarLayerProcessor$find_interval_grob(plot, gt, panel_ctx = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

The grob one of whose child elements is drawn per sample, or NULL when
it cannot be resolved

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$find_unnamed_interval_grob()`

Resolve the drawn grob of a layer ggplot2 left unnamed.

[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
and
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
draw a bare `GRID.polyline.N`, so there is no name to match on and
`find_layer_grob_tree()` returns NULL for them. Position is the
remaining handle: ggplot2 lays a panel out as the grill, a leading
`zeroGrob`, **one child per layer in layer order**, a trailing
`zeroGrob` and the border. A layer that draws nothing still takes its
slot as a `zeroGrob`, so the correspondence survives an empty layer
beside this one.

The leading blank is found by class rather than by an absent name: a
`zeroGrob` is named, and its name is the four characters `"NULL"`.

It is deliberately narrow. The result has to be a `polyline` for a geom
that is known to draw one, because a positional hit on the wrong layer
would highlight another layer's marks – worse than the missing highlight
this fixes, since a reader can hear nothing but cannot hear wrongness.

#### Usage

    Ggplot2ErrorbarLayerProcessor$find_unnamed_interval_grob(
      plot,
      gt,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

The layer's polyline grob, or NULL

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$interval_grob_shape()`

Count the samples a grob draws, and the elements each takes.

#### Usage

    Ggplot2ErrorbarLayerProcessor$interval_grob_shape(grob)

#### Arguments

- `grob`:

  The grob resolved for this layer

#### Returns

A list of `samples` and `per_sample`, or NULL when the grob is not one
of the shapes this has been verified against

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$grob_point_groups()`

Split a grob's points into one index vector per sample.

#### Usage

    Ggplot2ErrorbarLayerProcessor$grob_point_groups(grob)

#### Arguments

- `grob`:

  A `polygon` or `polyline` grob

#### Returns

A list of index vectors in drawing order, or NULL

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$drawn_run_count()`

Count the elements one sample of a grob is drawn as.

grid breaks a polyline at a missing point, and
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
uses that: its eight points per sample are `cap, NA, whisker, NA, cap`,
so the export carries three elements for the one bar. A run needs two
points to be a line at all, and a shorter one draws nothing.

#### Usage

    Ggplot2ErrorbarLayerProcessor$drawn_run_count(grob, index)

#### Arguments

- `grob`:

  A `polygon` or `polyline` grob

- `index`:

  The point indices belonging to one sample

#### Returns

How many elements that sample is drawn as

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$interval_selector()`

Build the CSS selector for one element per sample.

gridSVG wraps each grob in a `<g>` named after it with a `.1` suffix and
writes its elements inside in drawing order, so the samples are
addressable as a stride through that group's children.

Only the two strides that have been checked against an export are
emitted: one element per sample, and the three a
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
draws, of which the middle one is the whisker spanning the interval –
the cap either side of it says nothing a reader is navigating to. Any
other stride returns NULL and the layer goes back to highlighting
nothing, which is the honest answer for a shape nobody has looked at.

#### Usage

    Ggplot2ErrorbarLayerProcessor$interval_selector(grob_name, per_sample)

#### Arguments

- `grob_name`:

  The drawn grob's name

- `per_sample`:

  How many elements each sample is drawn as

#### Returns

A CSS selector, or NULL

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$extract_interval_data()`

Build the MAIDR points for this layer.

The emitted shape names the category `x` and the magnitude `y` in both
orientations, with the bounds in `yMin`/`yMax`, and lets `orientation`
say which is on screen where. That is the shape MAIDR's `ErrorBarTrace`
consumes: it reads the magnitude as `y`/`yMin`/`yMax` with no
orientation branch, so emitting screen-aligned keys would leave a
horizontal chart with no interval at all.

A row missing its bounds still emits its estimate. A one-sided interval
is a real chart, and dropping the point for want of its other half would
lose the estimate too.

A grouped layer emits one series per group instead, each point carrying
its group's name as `z` – the shape every other grouped layer in this
package already emits, and the one MAIDR's `ErrorBarTrace` reads as a
series of series.

#### Usage

    Ggplot2ErrorbarLayerProcessor$extract_interval_data(
      built,
      layer_data,
      is_horizontal,
      panel_id = NULL,
      groups = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  This layer's computed rows

- `is_horizontal`:

  Whether the interval spans the x axis

- `panel_id`:

  Panel ID for faceted plots (optional)

- `groups`:

  The layer's series split, or NULL for a single series

#### Returns

A list of MAIDR interval points, or a list of such lists when the layer
is grouped

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$resolve_estimates()`

Resolve the estimate each interval is centred on.

The estimate aesthetic is **optional** on these geoms, and leaving it
out is idiomatic rather than exotic: `geom_errorbar(aes(x, ymin, ymax))`
layered over a
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html) is
the standard way to draw a bar chart with error bars, and it builds with
no `y` column at all.
[`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
is the same. Requiring the column dropped every such layer silently – no
interval, no estimate, no error.

When it is absent the chart genuinely draws no estimate, only a span, so
the centre of that span is used. That is a property of the drawn bar
rather than a claim about an unobserved estimate, and it is what keeps
the bounds – which are the real data here – reachable at all. It is NOT
the mean for an asymmetric interval, and nothing here pretends it is: a
layer that carries `y` always uses the value the chart drew.

#### Usage

    Ggplot2ErrorbarLayerProcessor$resolve_estimates(
      layer_data,
      value_col,
      min_col,
      max_col
    )

#### Arguments

- `layer_data`:

  This layer's computed rows

- `value_col`:

  The estimate column for this orientation

- `min_col`:

  The lower bound column for this orientation

- `max_col`:

  The upper bound column for this orientation

#### Returns

A numeric vector of estimates, or NULL when neither the estimate nor a
pair of bounds is present

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$resolve_category_labels()`

Recover the names behind a discrete category axis.

ggplot2 maps a discrete axis onto integer positions before it computes
the layer, so the built data carries `1, 2, 3` where the chart draws
`control, high dose, low dose`. Announcing the positions would name
something the reader cannot find anywhere on the chart – and the
positions are assigned in the scale's order, not the data's, so they do
not even read as row numbers.

The labels come from the panel's scale rather than from the data frame,
which is what makes the position an index into them.

#### Usage

    Ggplot2ErrorbarLayerProcessor$resolve_category_labels(
      built,
      layer_data,
      category_col,
      panel_id = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  This layer's computed rows

- `category_col`:

  Which built column carries the category

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of labels – strings for a discrete axis, numbers for a continuous
one

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$category_axis_labels()`

Read the break labels of the category axis, when discrete.

#### Usage

    Ggplot2ErrorbarLayerProcessor$category_axis_labels(
      built,
      category_col,
      panel_id = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `category_col`:

  Which built column carries the category

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A character vector of labels, or NULL on a continuous axis

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2ErrorbarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
