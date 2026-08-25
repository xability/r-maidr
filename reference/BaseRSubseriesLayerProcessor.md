# Base R Seasonal Subseries Layer Processor

Reads [`monthplot()`](https://rdrr.io/r/stats/monthplot.html) as the set
of lines it draws: one series per cycle position – month, quarter,
whatever the frequency makes it – running over that position's own
subseries.

[`stats::monthplot.default`](https://rdrr.io/r/stats/monthplot.html)
draws exactly that, one
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) call per
position:

    for (i in 1L:f) {
      sub <- phase == i
      lines((y[sub] - min(y)) * scale - 0.45 + i, x[sub], type = type, ...)
    }

The x coordinate there is a slot offset, not a reading: every subseries
is squeezed into its own 0.9-wide band so twelve of them fit side by
side on one axis. What the offset is computed *from* is `times`, and
that is the reading – the cycle each observation falls in. So each
series comes out as its own subseries over `times`, carrying its
position's label as `z`, which is the shape
[BaseRLineLayerProcessor](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
already reads for `matplot`.

Recomputed from the recorded arguments rather than read back off the
drawing, for the reason the correlograms recompute theirs (#276): the
slot offsets are on the page and the times are not, and the offsets are
the half that carries no meaning.

## What is not read

`base` draws one horizontal segment per position at
`base(x[phase == i])` – the position's mean, by default – and those
segments are not emitted. There is no shape in the grammar for a
per-series reference level, and a series of its own would be wrong: the
twelve means run across the *cycle positions*, while every series here
runs across the *cycles*, so putting them in one layer would put two x
domains in it. Left to a maintainer with the grammar to change.

`type` does not change the reading, for the reason `interaction.plot`'s
does not change its own (#278): `"l"` and `"h"` draw the same subseries
with different marks, and reading the spikes as loose values would lose
the grouping that makes the chart a subseries plot.

It does change where the marks *are*, though. `"h"` is not handed to
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) the way a
`type` usually is – `monthplot` branches and calls
[`segments()`](https://r.maidr.ai/reference/base-r-wrappers.md) instead
– so the grobs land under `-segments-` and the inherited search for
`-lines-` finds nothing. A layer with no selectors is dropped by the
frontend's `selectors.length === series count` precondition, so the
chart would read correctly and highlight nothing at all. See
`selector_grob_type()` and `generate_selectors()` below.

A monthly series whose labels this reads rather than the caller writes
is named with [month.abb](https://rdrr.io/r/base/Constants.html) rather
than with `monthplot`'s own initials – see the note beside `ts_labels()`
for why the initials do not survive being announced.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRSubseriesLayerProcessor`

## Methods

### Public methods

- [`BaseRSubseriesLayerProcessor$extract_data()`](#method-BaseRSubseriesLayerProcessor-extract_data)

- [`BaseRSubseriesLayerProcessor$extract_axis_titles()`](#method-BaseRSubseriesLayerProcessor-extract_axis_titles)

- [`BaseRSubseriesLayerProcessor$generate_selectors()`](#method-BaseRSubseriesLayerProcessor-generate_selectors)

- [`BaseRSubseriesLayerProcessor$selector_grob_type()`](#method-BaseRSubseriesLayerProcessor-selector_grob_type)

- [`BaseRSubseriesLayerProcessor$clone()`](#method-BaseRSubseriesLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
- [`BaseRLineLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_main_title)
- [`BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)
- [`BaseRLineLayerProcessor$process()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-process)

------------------------------------------------------------------------

### `BaseRSubseriesLayerProcessor$extract_data()`

One series per cycle position, over that position's own subseries.

Built point by point rather than through `extract_multiline_data()`,
which takes a matrix and so would need the short positions padded. A
series of 48 monthly observations gives every month four cycles and pads
nothing; 50 gives January and February five and the other ten four, and
the padding would put two points on the chart that `monthplot` never
drew.

#### Usage

    BaseRSubseriesLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information for the recorded call

#### Returns

A list of series, each a list of `x`/`y`/`z` points

------------------------------------------------------------------------

### `BaseRSubseriesLayerProcessor$extract_axis_titles()`

The labels the drawing writes.

`monthplot`'s own `ylab` default is `deparse1(substitute(x))`, so it
names the *expression* the caller wrote. The wrapper records evaluated
values, by which point
[`substitute()`](https://rdrr.io/r/base/substitute.html) is gone, so the
expression comes off the recorded call text instead, the way the
correlograms recover their series names (#276).

There is no default for `xlab`: `monthplot` blanks it unless the caller
passes one, because the axis it writes carries the cycle labels and not
a quantity. An unset label is left unset rather than invented.

#### Usage

    BaseRSubseriesLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information for the recorded call

#### Returns

An `axes` list from
[`build_axes()`](https://r.maidr.ai/reference/build_axes.md)

------------------------------------------------------------------------

### `BaseRSubseriesLayerProcessor$generate_selectors()`

The selectors, with the base line's grob left out of them.

`monthplot` draws the `base` reference segments in one
[`segments()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
*before* the loop, so on a `type = "h"` chart the first `-segments-`
grob is the twelve means and the rest are the twelve subseries. Handed
over as they are, every series would be outlined on the position before
it.

A count that is not exactly one more than the series drops the selectors
rather than guessing which grob is which: outlining the wrong spikes is
worse than outlining none.

`base = NULL` would remove the extra grob, and cannot arrive here:
`monthplot(x, type = "h", base = NULL)` raises
`object 'means' not found` inside `stats` – measured – because the `"h"`
branch reads a `means` the `base` guard never computed. A call that
raised is never recorded.

#### Usage

    BaseRSubseriesLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information for the recorded call

- `gt`:

  The gtable the drawing was exported to

#### Returns

A list of CSS selectors, one per series

------------------------------------------------------------------------

### `BaseRSubseriesLayerProcessor$selector_grob_type()`

Which family of grob names this layer's selectors come from.

`-segments-` when the spikes were drawn, `-lines-` otherwise. Public
because the parent's is: `generate_selectors_from_grob()` reaches it
through `self$`, which finds nothing private.

#### Usage

    BaseRSubseriesLayerProcessor$selector_grob_type(layer_info)

#### Arguments

- `layer_info`:

  Layer information for the recorded call

#### Returns

`"segments"` or `"lines"`

------------------------------------------------------------------------

### `BaseRSubseriesLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSubseriesLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
