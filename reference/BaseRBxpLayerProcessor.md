# Base R bxp() Layer Processor

Reads a [`graphics::bxp()`](https://rdrr.io/r/graphics/bxp.html) call as
the box plot it draws.

[`bxp()`](https://rdrr.io/r/graphics/bxp.html) is the drawing half of
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md):
[`boxplot.default()`](https://rdrr.io/r/graphics/boxplot.html) computes
the five-number summaries and then hands them to
[`bxp()`](https://rdrr.io/r/graphics/bxp.html), which puts the boxes,
whiskers, medians and outliers on the page. Calling it directly is how a
caller draws boxes from summaries they already have – from
`boxplot(plot = FALSE)`, from
[`boxplot.stats()`](https://rdrr.io/r/grDevices/boxplot.stats.html), or
computed elsewhere entirely – and it is one of the twelve calls \#262
found drawing while the save reported no plot at all.

### What is the same, and what is not

The marks are identical. Drawn off-screen and echoed through
`gridGraphics`, `bxp(z)` and the
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call that
produced `z` emit the same grob names in the same order – `polygon-1`,
`segments-1`, `points-1`, ... – because the same code drew them. Every
selector `BaseRBoxplotLayerProcessor` builds, including the index shift
each box with no outliers puts on the boxes after it, therefore
addresses a [`bxp()`](https://rdrr.io/r/graphics/bxp.html) chart
unchanged, and this class inherits all of it.

The one difference is where the summaries come from.
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is handed
observations, so its processor replays `boxplot(plot = FALSE)` to
recover them; [`bxp()`](https://rdrr.io/r/graphics/bxp.html) is handed
the summaries themselves, in its first argument. Replaying
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) on *that*
would read the six-element list as six groups of numbers and summarise
them – so the only thing this class overrides is `read_stats()`.

Two things [`bxp()`](https://rdrr.io/r/graphics/bxp.html) shares with
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) are
shared including their limits: `horizontal = TRUE` means the same thing
to both, and `at =` repositions boxes without reordering the drawing in
either, so a non-monotonic `at` reads in drawing order here exactly as
it already does for
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md).

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRBoxplotLayerProcessor`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.md)
-\> `BaseRBxpLayerProcessor`

## Methods

### Public methods

- [`BaseRBxpLayerProcessor$read_stats()`](#method-BaseRBxpLayerProcessor-read_stats)

- [`BaseRBxpLayerProcessor$clone()`](#method-BaseRBxpLayerProcessor-clone)

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)
- [`BaseRBoxplotLayerProcessor$determine_orientation()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-determine_orientation)
- [`BaseRBoxplotLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-extract_axis_titles)
- [`BaseRBoxplotLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-extract_data)
- [`BaseRBoxplotLayerProcessor$extract_formula_labels()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-extract_formula_labels)
- [`BaseRBoxplotLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-extract_main_title)
- [`BaseRBoxplotLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-generate_selectors)
- [`BaseRBoxplotLayerProcessor$process()`](https://r.maidr.ai/reference/BaseRBoxplotLayerProcessor.html#method-process)

------------------------------------------------------------------------

### `BaseRBxpLayerProcessor$read_stats()`

#### Usage

    BaseRBxpLayerProcessor$read_stats(args)

------------------------------------------------------------------------

### `BaseRBxpLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBxpLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
