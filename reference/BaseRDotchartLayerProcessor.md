# Base R Dot Chart Layer Processor

Processes Base R
[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) layers –
a Cleveland dot plot: one value per category, marked with a dot on a
horizontal guide line, with the categories running down the page.

Read as a `dot` layer, which the core builds on `BarTrace`: a bar
chart's reading with a different mark. The guide lines and the category
labels are frame rather than data – gridGraphics draws them as
`-abline-h-` and `-mtext-left-`, and only the dots carry a value.

`orientation` is `"horz"`, which is not a detail:
[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) puts the
categories on the vertical axis and the value along the horizontal one,
and the core reads a `horz` layer's magnitude from `x` and its category
from `y`. Without the key the layer defaults to vertical and reads the
category name where the magnitude belongs – no number to pitch, and the
announcement inverted (#184, \#480).

The dots are emitted in the order
[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) was
handed them, which is bottom-up on the drawn chart – base R puts the
first element at the bottom. That is the arrangement
`barplot(horiz = TRUE)` already ships for the same reason, so the two
horizontal base R charts read from the same end.

Selectors come from the points grob, which is the one thing a dotchart
shares with a scatter: `graphics-plot-N-points-1` holds one `<use>` per
dot. So this inherits `BaseRPointLayerProcessor` and replaces what is
read out of the call rather than how the marks are addressed.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRPointLayerProcessor`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.md)
-\> `BaseRDotchartLayerProcessor`

## Methods

### Public methods

- [`BaseRDotchartLayerProcessor$process()`](#method-BaseRDotchartLayerProcessor-process)

- [`BaseRDotchartLayerProcessor$extract_data()`](#method-BaseRDotchartLayerProcessor-extract_data)

- [`BaseRDotchartLayerProcessor$clone()`](#method-BaseRDotchartLayerProcessor-clone)

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
- [`BaseRPointLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-extract_main_title)
- [`BaseRPointLayerProcessor$formula_variables()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-formula_variables)
- [`BaseRPointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-generate_selectors)
- [`BaseRPointLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-needs_reordering)
- [`BaseRPointLayerProcessor$resolve_coordinates()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-resolve_coordinates)

------------------------------------------------------------------------

### `BaseRDotchartLayerProcessor$process()`

Process the dot chart layer.

#### Usage

    BaseRDotchartLayerProcessor$process(
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

List with data, selectors, type, title, axes and orientation

------------------------------------------------------------------------

### `BaseRDotchartLayerProcessor$extract_data()`

Read the dots out of the recorded
[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) call.

`dotchart(x, labels = NULL, ...)` names its dots from `labels` when the
caller gives them and from `names(x)` otherwise, which is what the chart
draws down its left margin. A vector with neither is drawn against blank
labels, and is emitted here against its positions so a reader still has
something to navigate by.

`x` and `y` carry the magnitude and the category respectively, which is
the arrangement a `horz` layer means – see the class note.

#### Usage

    BaseRDotchartLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

List of `x`/`y` points, empty when there is nothing to read

------------------------------------------------------------------------

### `BaseRDotchartLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRDotchartLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
