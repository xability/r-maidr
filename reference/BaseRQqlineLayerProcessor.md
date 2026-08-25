# Base R Q-Q Reference Line Layer Processor

Reads [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the reference line it draws.

[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) became
readable in \#251, and
[`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) – how
nearly every Q-Q plot in the wild is finished – was listed in `LOW` with
no reading at all, purely so a chart carrying one would decline rather
than come out as a scatter with a drawn mark silently missing from it.
That was the lower of the two claims; this is the reading (#252).

### Why it is recorded at all

[`stats::qqline()`](https://rdrr.io/r/stats/qqnorm.html) ends in
`abline(int, slope, ...)`, and that call is reached from *inside* the
`stats` namespace, where maidr's search-path wrapper never sees it.
Measured: before `qqline` was listed, `qqnorm(x); qqline(x)` recorded
exactly one call and the reference line left no trace.

### Where the endpoints come from

Not from the drawn grob and not re-derived.
[`stats::qqline`](https://rdrr.io/r/stats/qqnorm.html)'s body is four
lines, and the line it draws is the one through two points:

    y <- quantile(y, probs, names = FALSE, type = qtype, na.rm = TRUE)
    x <- distribution(probs)

with `probs` defaulting to `c(0.25, 0.75)` and `distribution` to
`qnorm`. This class asks `stats` for the same two anchors, from the
**call's own** arguments, so a
[`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) written
with a non-default `probs`, `qtype` or `distribution` is read from what
it was given rather than from the defaults. `datax = TRUE` swaps which
of the two the slope is taken over, and
[`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes its
own copy of that argument rather than inheriting the plot's – so a
`qqline(datax = TRUE)` over a `qqnorm(datax = FALSE)` is expressible,
and is read from the `qqline` call.

### Why the x range is not the parent's

`BaseRLineLayerProcessor$extract_abline_data()` takes its x range from
`get_x_range_from_group()`, which reads the group's HIGH call's first
argument as the x data. On a `qqnorm` group that argument is the
**sample**, not the theoretical quantiles the chart puts on x – so
inheriting it would stretch the line across the wrong interval, which is
the class of mistake the Q-Q reading exists to avoid. The range comes
from the drawn pairs instead, which @code BaseRQqLayerProcessor already
computes from `stats`' own output.

Highlighting needs nothing new: `qqnorm(x); qqline(x)` and
`plot(x, y); abline(0, 1)` export the *same* grob,
`graphics-plot-1-abline-ab-1`, so the parent's abline selector reaches
it unchanged.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRQqlineLayerProcessor`

## Methods

### Public methods

- [`BaseRQqlineLayerProcessor$extract_data()`](#method-BaseRQqlineLayerProcessor-extract_data)

- [`BaseRQqlineLayerProcessor$reference_line()`](#method-BaseRQqlineLayerProcessor-reference_line)

- [`BaseRQqlineLayerProcessor$qq_x_range()`](#method-BaseRQqlineLayerProcessor-qq_x_range)

- [`BaseRQqlineLayerProcessor$selector_grob_type()`](#method-BaseRQqlineLayerProcessor-selector_grob_type)

- [`BaseRQqlineLayerProcessor$named_or_first()`](#method-BaseRQqlineLayerProcessor-named_or_first)

- [`BaseRQqlineLayerProcessor$clone()`](#method-BaseRQqlineLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_axis_titles)
- [`BaseRLineLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_main_title)
- [`BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`BaseRLineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors)
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)
- [`BaseRLineLayerProcessor$process()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-process)

------------------------------------------------------------------------

### `BaseRQqlineLayerProcessor$extract_data()`

Extract the two endpoints the reference line is drawn between

#### Usage

    BaseRQqlineLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of one series, each point a list of x and y

------------------------------------------------------------------------

### `BaseRQqlineLayerProcessor$reference_line()`

The intercept and slope
[`stats::qqline`](https://rdrr.io/r/stats/qqnorm.html) computes

Reproduces the four lines of
[`stats::qqline`](https://rdrr.io/r/stats/qqnorm.html)'s own body
against the recorded arguments, defaults included. Returns NULL when the
call did not carry a sample this can read, or when the anchors come back
degenerate – two equal quantiles give a slope of `Inf` or `NaN`, and a
line through them is not a line the chart drew.

#### Usage

    BaseRQqlineLayerProcessor$reference_line(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List with intercept and slope, or NULL

------------------------------------------------------------------------

### `BaseRQqlineLayerProcessor$qq_x_range()`

The x interval the chart drew, taken from the Q-Q pairs

The group's HIGH call is the
[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) this line
sits on, and its recorded first argument is a *sample* rather than
either drawn coordinate. So the range is read off the pairs `stats`
computes, which is what the chart put on the x axis.

#### Usage

    BaseRQqlineLayerProcessor$qq_x_range(layer_info)

#### Arguments

- `layer_info`:

  Layer information carrying the group

#### Returns

Numeric of length two, or NULL

------------------------------------------------------------------------

### `BaseRQqlineLayerProcessor$selector_grob_type()`

Which grob family this layer's selectors are drawn from

[`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) ends in
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md), so the
mark it leaves is an abline's: `qqnorm(x); qqline(x)` and
`plot(x, y); abline(0, 1)` export the same
`graphics-plot-1-abline-ab-1`. The parent keys this off the recorded
function name, which here is `qqline` rather than `abline`, so without
the override the selector would look under `lines` and find nothing –
announcing the line correctly and highlighting nothing, which is the
shape of defect \#145 was about.

#### Usage

    BaseRQqlineLayerProcessor$selector_grob_type(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

The grob family name

------------------------------------------------------------------------

### `BaseRQqlineLayerProcessor$named_or_first()`

A named argument, or the first positional one

#### Usage

    BaseRQqlineLayerProcessor$named_or_first(args, name)

#### Arguments

- `args`:

  The recorded arguments

- `name`:

  The formal's name

#### Returns

The value, or NULL

------------------------------------------------------------------------

### `BaseRQqlineLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRQqlineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
