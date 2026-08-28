# Base R Correlogram Layer Processor

Processes the three correlogram entry points –
[`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md). Each draws
one vertical spike per lag, from the zero line to the correlation at
that lag, and joins nothing to anything.

Read as a `lollipop` layer, for the reason `BaseRSpikeLayerProcessor`
gives: a line would say the samples are joined and that the space
between two lags can be interpolated, which is the one relationship a
correlogram is drawn to deny. The spikes even export under the same grob
name – measured, `plot(acf(v))` names them `graphics-plot-1-spike-1` –
so the inherited selector search needs no override.

What this adds is where the numbers come from. The recorded call holds
the **series**, not the correlogram: measured, `acf(v, lag.max = 5)`
records one HIGH call whose args are the 60 observations and `lag.max`.
So the reading replays the call with `plot = FALSE` and takes `$lag` and
`$acf` off the result, which is the same shape
`BaseRSpineplotLayerProcessor` takes for a table it cannot read off the
drawing either.

All three differ in what the lags are, and the replay answers that too
rather than the reading assuming it. Measured on one 60-point series:

    acf(v,  lag.max = 5)   lags  0  1  2  3  4  5
    pacf(v, lag.max = 5)   lags     1  2  3  4  5
    ccf(v, w, lag.max = 3) lags -3 -2 -1  0  1  2  3

`acf` starts at lag 0, whose correlation is 1 by construction and which
the chart draws; `pacf` has no lag 0 at all; and a cross-correlation's
lags are signed, because "x leads y" and "y leads x" are different
statements. Announcing any of the three as another would misname every
spike on the chart.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\>
[`BaseRSpikeLayerProcessor`](https://r.maidr.ai/reference/BaseRSpikeLayerProcessor.md)
-\> `BaseRCorrelogramLayerProcessor`

## Methods

### Public methods

- [`BaseRCorrelogramLayerProcessor$process()`](#method-BaseRCorrelogramLayerProcessor-process)

- [`BaseRCorrelogramLayerProcessor$extract_data()`](#method-BaseRCorrelogramLayerProcessor-extract_data)

- [`BaseRCorrelogramLayerProcessor$extract_axis_titles()`](#method-BaseRCorrelogramLayerProcessor-extract_axis_titles)

- [`BaseRCorrelogramLayerProcessor$extract_main_title()`](#method-BaseRCorrelogramLayerProcessor-extract_main_title)

- [`BaseRCorrelogramLayerProcessor$clone()`](#method-BaseRCorrelogramLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`BaseRLineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors)
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)
- [`BaseRSpikeLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRSpikeLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRCorrelogramLayerProcessor$process()`

Process the correlogram layer.

#### Usage

    BaseRCorrelogramLayerProcessor$process(
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

  Unused for Base R (kept for interface compatibility)

- `layout`:

  Unused for Base R (kept for interface compatibility)

- `built`:

  Unused for Base R (kept for interface compatibility)

- `gt`:

  Gtable object used for selector generation (optional)

- `grob_id`:

  Unused for Base R

- `panel_id`:

  Unused for Base R

- `panel_ctx`:

  Unused for Base R

- `layer_info`:

  Information about the recorded plot call

#### Returns

List with data, selectors, type, title and axes

------------------------------------------------------------------------

### `BaseRCorrelogramLayerProcessor$extract_data()`

Read one point per lag the correlogram draws.

The lag on the category axis and the correlation as the magnitude, in
the order they are drawn – which for `ccf` runs from the most negative
lag rightwards, so the announced order is the drawn one.

#### Usage

    BaseRCorrelogramLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

List of `x`/`y` points, empty when the replay states nothing

------------------------------------------------------------------------

### `BaseRCorrelogramLayerProcessor$extract_axis_titles()`

Name the lag axis and the quantity drawn against it.

A correlogram writes its own axis labels, so there is nothing the caller
titled to read – and the inherited `X`/`Y` fallback would name a lag
after a coordinate. The value axis follows what the replay says it
computed: `acf(type = "covariance")` draws covariances, not
correlations, and calling them correlations would announce a
normalisation the chart never applied.

#### Usage

    BaseRCorrelogramLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Named list with `x` and `y`

------------------------------------------------------------------------

### `BaseRCorrelogramLayerProcessor$extract_main_title()`

Title the chart the way the drawing does.

`plot.acf()` writes "Series v" above an `acf` and "v & w" above a `ccf`,
and the replayed object carries those as `$series` and `$snames` – but
not usefully. Both are `deparse(substitute(x))`, and the replay hands
`stats` the recorded *values* rather than the name the caller wrote, so
measured they come back as the whole series pasted in:
`Series c(-2.0715334064552, -0.117989125730012, ...)`. That is worse
than no title at all.

The name is in the recorded call expression instead, which is kept as
the source text of the call – measured, `"acf(v, lag.max = 3)"`. It is
used only when the argument is a bare symbol: a caller who wrote
`acf(rnorm(60))` named nothing, and titling the chart with the
expression that produced it would announce a call rather than a series.

A caller's own `main =` wins, which is what the inherited reading
already answers.

#### Usage

    BaseRCorrelogramLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

The title, or NULL when the caller named nothing

------------------------------------------------------------------------

### `BaseRCorrelogramLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRCorrelogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
