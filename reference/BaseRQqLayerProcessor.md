# Base R Q-Q Plot Layer Processor

Reads [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) as the
scatter of quantile pairs they draw.

A Q-Q plot is a scatter, and `BaseRPointLayerProcessor` already knows
how to emit one – the selector, the title and the grid all carry over
unchanged, and
[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) exports
its marks under `graphics-plot-N-points-1`, the same grob the point
processor looks for. What does not carry over is the **data**.

The base R processors read a call's *recorded arguments*, not the drawn
grob, and a Q-Q plot's arguments are not its coordinates. `qqnorm(y)` is
handed one sample and draws it against theoretical quantiles it
computes; `qqplot(x, y)` is handed two samples of possibly different
lengths and draws one interpolated pair per point of the shorter. Read
as an ordinary scatter, both would announce numbers the chart does not
draw – for `qqnorm` the raw sample on an axis of standard deviations,
which is the one reading a Q-Q plot most needs not to have, because the
whole point of the chart is the comparison between the two.

So the coordinates are not re-derived here. `stats` computes them and
both functions will hand them over without drawing: `plot.it = FALSE`
returns exactly the pairs the plotted call would have drawn. Forwarding
the recorded arguments rather than picking them apart is what makes the
awkward cases free. Measured on eight values against five:

    qqnorm(x, plot.it = FALSE)$x    theoretical quantiles, in the
                                    caller's order, not sorted
    qqnorm(x, datax = TRUE, ...)    the same pair, swapped
    qqplot(x, y, plot.it = FALSE)   both length 5; x interpolated to the
                                    shorter sample's quantiles

`datax` is the clearest of them: it swaps which axis holds the sample,
and forwarding it means nothing here has to know that.

The pairs come back in the order the call drew them, which is the order
the `points` grob lays its marks down in, so the selector list keeps
pairing positionally. Nothing is sorted.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRPointLayerProcessor`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.md)
-\> `BaseRQqLayerProcessor`

## Methods

### Public methods

- [`BaseRQqLayerProcessor$extract_data()`](#method-BaseRQqLayerProcessor-extract_data)

- [`BaseRQqLayerProcessor$quantile_pairs()`](#method-BaseRQqLayerProcessor-quantile_pairs)

- [`BaseRQqLayerProcessor$extract_axis_titles()`](#method-BaseRQqLayerProcessor-extract_axis_titles)

- [`BaseRQqLayerProcessor$default_axis_labels()`](#method-BaseRQqLayerProcessor-default_axis_labels)

- [`BaseRQqLayerProcessor$extract_main_title()`](#method-BaseRQqLayerProcessor-extract_main_title)

- [`BaseRQqLayerProcessor$clone()`](#method-BaseRQqLayerProcessor-clone)

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
- [`BaseRPointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-generate_selectors)
- [`BaseRPointLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-needs_reordering)
- [`BaseRPointLayerProcessor$process()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-process)

------------------------------------------------------------------------

### `BaseRQqLayerProcessor$extract_data()`

Extract the quantile pairs the call drew

#### Usage

    BaseRQqLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of points, each a list of x and y

------------------------------------------------------------------------

### `BaseRQqLayerProcessor$quantile_pairs()`

Ask `stats` for the pairs the call drew

Returns NULL when the computation raises or does not come back as a
usable pair of equal-length numeric vectors, which leaves the layer
empty and the chart on the fallback rather than shipping half of it.

#### Usage

    BaseRQqLayerProcessor$quantile_pairs(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List with x and y, or NULL

------------------------------------------------------------------------

### `BaseRQqLayerProcessor$extract_axis_titles()`

Axis labels and grid for a Q-Q plot

[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
"Theoretical Quantiles" against "Sample Quantiles" whenever the caller
does not, and `datax = TRUE` swaps them along with the axes – both are
constants in the function's own signature, so they are the labels the
chart really carries rather than a guess.

[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has no
such defaults: its are `deparse1(substitute(x))`, the caller's
expression, which is gone by the time the wrapper has recorded evaluated
values. So a
[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) the caller
did not label is left unlabelled for the renderer's generic, on the same
reasoning the point processor already states – a guessed noun is worse
than none.

The grid is computed from the drawn pairs, not from the recorded
arguments: those are the samples, and on `qqnorm` one of the two axes is
not a sample at all.

#### Usage

    BaseRQqLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRQqLayerProcessor$default_axis_labels()`

The labels the call writes when the caller does not

#### Usage

    BaseRQqLayerProcessor$default_axis_labels(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List with x and y, either a string or NULL

------------------------------------------------------------------------

### `BaseRQqLayerProcessor$extract_main_title()`

The title the call writes when the caller does not

[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s `main`
defaults to "Normal Q-Q Plot" and it is drawn, so announcing it is
reporting the chart rather than inventing a name for it.
[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has no
default title and gets none.

#### Usage

    BaseRQqLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

The title string

------------------------------------------------------------------------

### `BaseRQqLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRQqLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
