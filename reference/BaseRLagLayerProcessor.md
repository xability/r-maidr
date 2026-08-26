# Base R Lag Plot Processor

Reads [`lag.plot()`](https://rdrr.io/r/stats/lag.plot.html) as the grid
of scatters it draws: one panel per series and lag, the series plotted
against a shifted copy of itself.

**A grid, not a layer.** Like
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md), this call
lays out its own panels and hands nothing to the device's layout calls,
so the grid has to come from the reading. It answers
`multi_panel = TRUE` and places each layer at its own cell.

**What a panel pairs.** Measured by tracing
[`graphics::plot.xy`](https://rdrr.io/r/graphics/plot.xy.html) through a
real call – the panel is `plot(lag(X, k), X)`, and
[`lag()`](https://rdrr.io/r/stats/lag.html) shifts the time base *back*,
so the pair at time `t` is

    x = X[t + k]      the later reading, across
    y = X[t]          the earlier one, up

over every `t` where both indices land inside the series. A negative lag
works out of the same expression and was measured too: `set.lags = -1`
gives `x = X[1..n-1]` against `y = X[2..n]`, and `set.lags = 0` gives
the series against itself.

**The panels are numbered in draw order.** The nested loop runs series
outermost and lag innermost, and `par(mfrow)` fills row by row –
measured against a `grid.echo()` export, a two-column matrix at
`lags = 2` writes `graphics-plot-1` through `graphics-plot-4` for
`(a,1) (a,2) (b,1) (b,2)`. So panel `k` sits at row
`(k - 1) %/% ncols + 1`, column `(k - 1) %% ncols + 1`.

**A panel's marks are symbols or labels, and `labels` decides which.**
[`lag.plot()`](https://rdrr.io/r/stats/lag.plot.html) writes the time
index at each pair rather than a symbol when `labels` is true, and
`labels` defaults to `do.lines`, which defaults to `n <= 150` – so the
*default* chart is the labelled one. Measured, the four combinations
give:

    labels  do.lines   grobs in a panel
    FALSE   FALSE      points
    FALSE   TRUE       points, lines
    TRUE    FALSE      text
    TRUE    TRUE       text, brokenline

So `do.lines` only adds the joining line and `labels` alone decides the
mark, which is why the two are read separately rather than through the
default that ties them together.

Both marks can be outlined, and the export is what says so. Measured on
a real [`save_html()`](https://r.maidr.ai/reference/save_html.md) of a
labelled call, the text grob comes out as one group per pair, in data
order:

    <g id="graphics-plot-1-text-1.1">
      <g id="graphics-plot-1-text-1.1.1" transform="translate(254.32, …)">
      <g id="graphics-plot-1-text-1.1.2" transform="translate(221.70, …)">

which is the same shape a `points` grob has, with `use` elements
replaced by nested `g`s. So the selector differs only in the grob name
and the child it reaches for.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRPointLayerProcessor`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.md)
-\> `BaseRLagLayerProcessor`

## Methods

### Public methods

- [`BaseRLagLayerProcessor$process()`](#method-BaseRLagLayerProcessor-process)

- [`BaseRLagLayerProcessor$clone()`](#method-BaseRLagLayerProcessor-clone)

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
- [`BaseRPointLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_axis_titles)
- [`BaseRPointLayerProcessor$extract_base_r_axis_grid_info()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_base_r_axis_grid_info)
- [`BaseRPointLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_data)
- [`BaseRPointLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_main_title)
- [`BaseRPointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-generate_selectors)
- [`BaseRPointLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-needs_reordering)

------------------------------------------------------------------------

### `BaseRLagLayerProcessor$process()`

Emit one point layer per drawn panel

#### Usage

    BaseRLagLayerProcessor$process(
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

  Unused; the selectors are built rather than searched for.

- `grob_id`:

  Unused; present for the processor interface.

- `panel_id`:

  Unused; present for the processor interface.

- `panel_ctx`:

  Unused; present for the processor interface.

- `layer_info`:

  Layer information with the recorded call.

#### Returns

A multi-panel result, or NULL when nothing was read

------------------------------------------------------------------------

### `BaseRLagLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRLagLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
