# Base R Biplot Processor

Reads [`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the two things it draws: the observations in principal component space,
and the variables' loadings on the same components.

**It is a grid, and for a reason the other grids do not have.**
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) are read
as grids because they draw several panels. A biplot draws its two halves
*on top of each other* – but on **two different pairs of axes**, which
is the whole trick of the chart. Measured, the two `plot.xy` calls run
over different ranges, and the quantities behind them are different
sizes again:

    scores   PC1 range  -1.716 ..  2.199
    loadings PC1 range  -0.962 .. -0.012

Announcing both against one axis pair would misstate every loading. So
the two are given a cell each – one row, two columns – which is the only
way the existing grammar can say "these have separate scales" without
inventing a second axis on one layer.

**It draws no points at all.** Both `plot.xy` calls are `type = "n"`;
every mark on the page is a *label* or an *arrow*. Measured on the
export of a ten-observation, four-variable fit:

    graphics-plot-1-text-1     10 children   the observations
    graphics-plot-2-text-1      4 children   the variables
    graphics-plot-2-arrows-1    4 children   the arrows

Both text grobs are addressable per datum, in data order, which is the
shape [`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s
labelled panels already established – one `g` per label rather than one
`use` per symbol. The arrows are not emitted separately: an arrow and
its label name the same variable and sit at the same place, so the label
is the mark a reader is moved to.

**The values are the caller's, not the drawing's.**
[`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) apportions
the two halves between the axes so that both fit one page – it divides
the scores by `sdev * sqrt(n)` and multiplies the loadings by it, so
*neither* set is drawn at its own scale. What a reader wants is the pair
that mean something: the **scores**, an observation's coordinate in
component space, and the **loadings**, a variable's weight on each
component. Those are announced. This is the same choice
[`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) makes,
where the radii on the page are shares of a column's range and the
reading hands over the readings instead.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRPointLayerProcessor`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.md)
-\> `BaseRBiplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBiplotLayerProcessor$process()`](#method-BaseRBiplotLayerProcessor-process)

- [`BaseRBiplotLayerProcessor$clone()`](#method-BaseRBiplotLayerProcessor-clone)

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
- [`BaseRPointLayerProcessor$formula_variables()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-formula_variables)
- [`BaseRPointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-generate_selectors)
- [`BaseRPointLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-needs_reordering)
- [`BaseRPointLayerProcessor$resolve_coordinates()`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.html#method-resolve_coordinates)

------------------------------------------------------------------------

### `BaseRBiplotLayerProcessor$process()`

Emit the observations and the variables, a cell each

#### Usage

    BaseRBiplotLayerProcessor$process(
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

### `BaseRBiplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBiplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
