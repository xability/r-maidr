# Base R Term Plot Processor

Reads [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the partial-effect curves it draws: one panel per term, the term's
contribution to the fit plotted against its own carrier.

**A grid, not a layer.** Like
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md), one
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
draws several panels, and the orchestrator's ordinary multipanel path
cannot split them: `combine_layer_results()` maps a layer to a cell by
its *group* index, and one recorded call is one group, so every curve
would land in the same cell. So this answers `multi_panel = TRUE` and
places each curve at its own cell.

**The panels are pages, not terms.**
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) sets no
layout of its own – unlike
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md), which
calls `par(mfrow)` itself – so the caller's `par(mfrow)` decides how
many terms share a page, and R starts a new page when it runs out of
cells. Only the last page is exported. Measured on a three-term `lm`:

    no mfrow      (k = 1)   graphics-plot-1                 1 panel
    mfrow c(1,2)  (k = 2)   graphics-plot-1                 1 panel
    mfrow c(1,3)  (k = 3)   graphics-plot-1 .. -3           3 panels
    mfrow c(2,2)  (k = 4)   graphics-plot-1 .. -3           3 panels

So with `n` terms and `k` cells the page carries the **last**
`((n - 1) %% k) + 1` of them, which is the rule
[`compute_panel_slots()`](https://r.maidr.ai/reference/compute_panel_slots.md)
already applies to whole plot groups – the same arithmetic, one level
down. A reading that announced all `n` terms would name curves that are
not on the page.

The `par` call is recorded as LAYOUT rather than as a layer, so it does
not reach the processor with the rest of the call. It is read off the
device the call was recorded on, through the same
[`detect_panel_configuration()`](https://r.maidr.ai/reference/detect_panel_configuration.md)
the orchestrator uses, so the two cannot disagree about the grid.

**What a panel draws.** The curve is the term's fitted contribution,
`predict(model, type = "terms")[, term]`, against that term's carrier
from the model frame, in increasing carrier order – which is the order
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) sorts
them into before drawing. With `partial.resid = TRUE` it adds the
partial residuals, `contribution + residuals(model)`, as points beside
the curve; measured, that is a second grob in the same panel:

    termplot(fit)                     panel k: lines-1
    termplot(fit, partial.resid = T)  panel k: lines-1 and points-1

The points are left for a follow-up rather than emitted as a second
layer: they are a different reading of the same panel, and the curve is
the thing
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) exists
to draw.

**A factor term is declined.**
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws it
as a step function over the levels, which is neither this line nor a
bar, and reading it as a line would announce a slope between levels that
have no order. It is left out of the grid rather than given a wrong
shape.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRTermplotLayerProcessor`

## Methods

### Public methods

- [`BaseRTermplotLayerProcessor$process()`](#method-BaseRTermplotLayerProcessor-process)

- [`BaseRTermplotLayerProcessor$clone()`](#method-BaseRTermplotLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_axis_titles)
- [`BaseRLineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_data)
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
- [`BaseRLineLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRTermplotLayerProcessor$process()`

Emit one line layer per drawn panel

#### Usage

    BaseRTermplotLayerProcessor$process(
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

### `BaseRTermplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRTermplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
