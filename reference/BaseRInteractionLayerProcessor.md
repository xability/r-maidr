# Base R Interaction Plot Layer Processor

Reads
[`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
as the set of lines it draws: one series per level of the trace factor,
running across the levels of the x factor at `fun(response)` for each
cell.

[`stats::interaction.plot`](https://rdrr.io/r/stats/interaction.plot.html)
computes that grid itself and hands it straight to `matplot`:

    cells <- tapply(response, list(x.factor, trace.factor), fun)
    matplot(xvals, cells, ..., type = type, ...)

which is the shape
[BaseRLineLayerProcessor](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
already reads for `matplot` – one series per column, each point carrying
its column name as `z`. So the whole reading is recomputing `cells` and
handing it over; nothing about extracting a multi-series line is new
here.

Recomputed rather than read back off the drawing, for the reason the
correlograms recompute theirs (#276): a cell mean is not on the page in
any form a grob carries, and the recorded arguments hold everything
needed to get it exactly as the function did.

`type` is not consulted. It varies the marks – `"l"` draws lines, `"p"`
points, `"b"`/`"o"`/`"c"` both – but every variant draws the same cell
means in the same series, and reading a `type = "p"` chart as loose
points would lose the trace grouping that makes it an interaction plot.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRInteractionLayerProcessor`

## Methods

### Public methods

- [`BaseRInteractionLayerProcessor$extract_data()`](#method-BaseRInteractionLayerProcessor-extract_data)

- [`BaseRInteractionLayerProcessor$extract_axis_titles()`](#method-BaseRInteractionLayerProcessor-extract_axis_titles)

- [`BaseRInteractionLayerProcessor$clone()`](#method-BaseRInteractionLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$axis_extent()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-axis_extent)
- [`BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
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
- [`BaseRLineLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRInteractionLayerProcessor$extract_data()`

One series per trace level, read from the grid of cell means

#### Usage

    BaseRInteractionLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of series

------------------------------------------------------------------------

### `BaseRInteractionLayerProcessor$extract_axis_titles()`

The three labels the drawing writes, each explicit argument first.

All three of `interaction.plot`'s own defaults are
`deparse1(substitute(...))` of an argument, so they name the
*expression* the caller wrote. The wrapper records evaluated values, by
which point [`substitute()`](https://rdrr.io/r/base/substitute.html) is
long gone – a factor's levels are not its name – so the expressions come
off the recorded call text instead, the way the correlograms recover
their series names (#276).

#### Usage

    BaseRInteractionLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information for the recorded call

#### Returns

An `axes` list from
[`build_axes()`](https://r.maidr.ai/reference/build_axes.md)

------------------------------------------------------------------------

### `BaseRInteractionLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRInteractionLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
