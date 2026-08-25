# Base R Strip Chart Layer Processor

Reads [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md)
as the one-dimensional scatter it draws: every observation as its own
mark, laid along a value axis at its group's position.

**One layer per group.** That is the shape of the reading and it is
forced by the drawing rather than chosen for tidiness: measured on two
groups, gridGraphics exports

    graphics-plot-1-points-1
    graphics-plot-1-points-2

– one `points` grob per group – and
[`find_graphics_plot_grob()`](https://r.maidr.ai/reference/find_graphics_plot_grob.md)
answers with the first match, so a single layer would announce every
observation and highlight only the first group's. It is also the reading
the same chart already gets in py-maidr, whose `stripplot` and
`swarmplot` split into one named layer per category.

**The groups are not re-derived.** `stripchart` forms them in two places
and both are read rather than reimplemented:

    stripchart.default   groups <- if (is.list(x)) x
                                   else if (is.numeric(x)) list(x)
    stripchart.formula   split(mf[[response]], mf[-response])
                         after stats::model.frame

so a list keeps its own names, a bare vector is one unnamed group, and a
formula is split by [`split()`](https://rdrr.io/r/base/split.html)
itself.

**A formula with no `data =` is read too**, which is worth stating
because the opposite is the obvious guess. A formula carries the
environment it was written in, and the recorded call holds the formula,
so that environment is still reachable when the chart is read;
[`model.frame()`](https://rdrr.io/r/stats/model.frame.html) resolves the
variables from it exactly as `stripchart.formula` did when it drew them.
Measured on `stripchart(len ~ supp)` with the variables local to a
function, global, and in a closure whose call had returned – all three
read back the drawn groups and values. This is also what
`BaseRBoxplotLayerProcessor` already does with its
`data = args[["data"]]`.

What that inherits is the hazard of a late lookup: rebinding `len`
between the drawing and the rendering makes the payload announce the new
values. Measured, and filed as \#254 – it belongs to every recorded
formula in this package rather than to this processor, and refusing the
ordinary spelling to dodge it would trade a chart that reads exactly for
a picture.

**The position stays a number.** `ScatterPoint.x` is typed `number` in
the grammar and `ScatterTrace` does arithmetic on it, so the group's
name travels beside its position in `yLabel` – or `xLabel` on a vertical
chart – exactly as the ggplot2 point processor does since \#178.

**`method = "jitter"` is not a reading problem here**, and that is worth
saying because it is one for
[`geom_jitter()`](https://ggplot2.tidyverse.org/reference/geom_jitter.html)
(#174). A stripchart jitters along the *group* axis only; the value axis
is untouched, so every number announced is the observation itself. What
is displaced is the position whose name is already carried as a label.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRPointLayerProcessor`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.md)
-\> `BaseRStripchartLayerProcessor`

## Methods

### Public methods

- [`BaseRStripchartLayerProcessor$process()`](#method-BaseRStripchartLayerProcessor-process)

- [`BaseRStripchartLayerProcessor$extract_groups()`](#method-BaseRStripchartLayerProcessor-extract_groups)

- [`BaseRStripchartLayerProcessor$draws_horizontally()`](#method-BaseRStripchartLayerProcessor-draws_horizontally)

- [`BaseRStripchartLayerProcessor$extract_axis_titles()`](#method-BaseRStripchartLayerProcessor-extract_axis_titles)

- [`BaseRStripchartLayerProcessor$split_by_formula()`](#method-BaseRStripchartLayerProcessor-split_by_formula)

- [`BaseRStripchartLayerProcessor$group_names()`](#method-BaseRStripchartLayerProcessor-group_names)

- [`BaseRStripchartLayerProcessor$group_positions()`](#method-BaseRStripchartLayerProcessor-group_positions)

- [`BaseRStripchartLayerProcessor$group_points()`](#method-BaseRStripchartLayerProcessor-group_points)

- [`BaseRStripchartLayerProcessor$group_selectors()`](#method-BaseRStripchartLayerProcessor-group_selectors)

- [`BaseRStripchartLayerProcessor$clone()`](#method-BaseRStripchartLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
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
- [`BaseRPointLayerProcessor$extract_base_r_axis_grid_info()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_base_r_axis_grid_info)
- [`BaseRPointLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_data)
- [`BaseRPointLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_main_title)
- [`BaseRPointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-generate_selectors)
- [`BaseRPointLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-needs_reordering)

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$process()`

Emit one point layer per drawn group

#### Usage

    BaseRStripchartLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
    )

#### Arguments

- `plot`:

  Unused; present for the processor interface.

- `layout`:

  Unused; present for the processor interface.

- `built`:

  Unused; present for the processor interface.

- `gt`:

  The grob tree, for the selectors.

- `grob_id`:

  Unused; present for the processor interface.

- `panel_id`:

  Unused; present for the processor interface.

- `panel_ctx`:

  Unused; present for the processor interface.

- `layer_info`:

  Layer information with the recorded call.

#### Returns

A multi-layer result, or NULL when nothing was read

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$extract_groups()`

The groups
[`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) itself
would form

Read from the recorded call rather than re-derived, per the two
spellings in the class docs. Returns an empty list for anything this
cannot resolve exactly, which leaves the chart on the static fallback.

#### Usage

    BaseRStripchartLayerProcessor$extract_groups(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call.

#### Returns

A named list of numeric vectors, one per group

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$draws_horizontally()`

Which visual axis the observations run along

[`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
horizontally unless told otherwise, which is the opposite of
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s default
and worth reading from the call rather than assuming.

#### Usage

    BaseRStripchartLayerProcessor$draws_horizontally(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call.

#### Returns

TRUE when the values run left to right

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$extract_axis_titles()`

Name the value axis and the group axis

Overrides the inherited scatter helper, which reads the recorded `x` as
a pair of coordinates and so gets a stripchart wrong in both directions
at once. Measured on `stripchart(c(3.1, 4.2, 5.0, 2.2, 6.9))`, that
helper hands the bare vector to
[`xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html), which reads
it as y and indexes x over `1:5`:

    announced   x  1 .. 5        y  2 .. 7
    drawn       x  2.2 .. 6.9    y  one group, at 1

– the value range offered on the group axis, and a bare index on the
value axis. A stripchart is one categorical axis against one measured
axis, the same shape
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draw, so
it is named the same way and by the same helper; `vertical = TRUE` swaps
which visual axis holds which, exactly as `horizontal = TRUE` does
there.

No range is emitted for either axis. The group axis has none to give –
its positions are names – and the value axis is left to the renderer's
own generic, which is where every other grouped base R chart leaves it.

#### Usage

    BaseRStripchartLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call.

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$split_by_formula()`

Split a formula's response by its grouping columns

`stripchart.formula` does exactly this, through
[`stats::model.frame`](https://rdrr.io/r/stats/model.frame.html) and
`split`, so both are called rather than imitated. `data` is passed
through exactly as recorded – a data frame, a plain list, or NULL –
because [`model.frame()`](https://rdrr.io/r/stats/model.frame.html)
accepts all three, and NULL is its own default for "resolve from the
formula's environment", which is what the drawing did. Coercing it first
bought nothing: measured, `as.data.frame(NULL)` and NULL produce the
same split. This is the spelling `BaseRBoxplotLayerProcessor` already
uses.

A one-sided formula needs no guard of its own. `stripchart(~ len)` does
not draw at all – `stripchart.formula` stops with "formula missing or
incorrect" – so it cannot be recorded, and reached directly it gives
`response == 0`, whose `frame[[0]]` the `tryCatch` below already turns
into the decline.

#### Usage

    BaseRStripchartLayerProcessor$split_by_formula(formula, data, frame = NULL)

#### Arguments

- `formula`:

  The recorded formula.

- `data`:

  The recorded `data` argument, or NULL.

- `frame`:

  The model frame kept when the call was recorded, or NULL for a call
  recorded before that existed.

#### Returns

A named list of numeric vectors, or NULL

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$group_names()`

The names
[`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
down the group axis

`group.names` first, then the list's own names, then the positions – the
order `stripchart.default` resolves them in. A `group.names` of the
wrong length is ignored here because it is ignored there.

#### Usage

    BaseRStripchartLayerProcessor$group_names(args, groups)

#### Arguments

- `args`:

  The recorded argument list.

- `groups`:

  The groups already formed.

#### Returns

One name per group

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$group_positions()`

Where along the group axis each group was drawn

`at` when the caller gave one of the right length, and `1:n` otherwise,
which is what `stripchart.default` falls back to.

#### Usage

    BaseRStripchartLayerProcessor$group_positions(layer_info, count)

#### Arguments

- `layer_info`:

  Layer information with the recorded call.

- `count`:

  How many groups there are.

#### Returns

One numeric position per group

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$group_points()`

One group's observations, as points

The value goes on the value axis and the position on the group axis, and
the group's name travels beside the position as a label rather than in
place of it – `ScatterPoint.x` is typed `number` and `ScatterTrace` does
arithmetic on it (#178).

#### Usage

    BaseRStripchartLayerProcessor$group_points(values, label, position, horizontal)

#### Arguments

- `values`:

  The group's observations.

- `label`:

  The group's name.

- `position`:

  Where the group sits on its axis.

- `horizontal`:

  TRUE when the values run left to right.

#### Returns

A list of points

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$group_selectors()`

The marks one group was drawn into

Built rather than searched for.
[`find_graphics_plot_grob()`](https://r.maidr.ai/reference/find_graphics_plot_grob.md)
answers with the first `points` grob of the plot, and a stripchart draws
one per group, so a search would give every layer the first group's
marks. The names are `graphics-plot-{plot}-points-{group}`, measured
against a real `gridSVG` export, and every emitted selector was then
resolved in Chromium against a rendering of a three-group chart: 5, 4
and 2 elements, one per observation.

#### Usage

    BaseRStripchartLayerProcessor$group_selectors(layer_info, index)

#### Arguments

- `layer_info`:

  Layer information with the recorded call.

- `index`:

  Which group this is, from 1.

#### Returns

A one-element list of selectors

------------------------------------------------------------------------

### `BaseRStripchartLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStripchartLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
