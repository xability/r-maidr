# Base R Association Plot Layer Processor

Processes Base R
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) layers
– a Cohen–Friendly association plot, which draws one tile per cell of a
two-way table whose signed height is that cell's Pearson residual,
`(observed - expected) / sqrt(expected)`.

Read as a `heat` layer, because a named grid of one number per cell is
what the chart states and row-then-column is how a reader navigates a
contingency table. Measured on `assocplot(HairEyeColor[, , 1])`, the
rects the drawing produces carry the residuals exactly:


           Brown    Blue   Hazel   Green
    Black  2.780  -2.059   0.184  -1.408
    Brown  0.391  -0.246   0.185  -0.465
    Red   -0.562  -0.658   0.532   1.485
    Blond -3.273   3.271  -0.988   1.097

Nothing is inferred from the drawing:
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
handed the table, so the recorded call carries every number the trace
wants. It returns `NULL`, which is why the reading comes from the
argument – the shape [`bxp()`](https://rdrr.io/r/graphics/bxp.html)'s
reading took in \#265.

### Two things this deliberately does not do

**The tile width is dropped.** Each tile is drawn `sqrt(expected)` wide,
so the marginals are on the chart as a second encoding. A `heat` layer
has no width, and the residual is what an association plot exists to
show – the eye reads height and sign, and the width is why a cell's box
is wider rather than a value the reader is asked to compare. Announcing
it in `z` instead would replace the number the chart is about.

**It is not a `mosaic`.**
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
read as one and the two look alike, but a mosaic's tiles tile the space
and carry proportions of a whole. These float above and below a baseline
and carry residuals, which are signed and sum to nothing. Calling it a
mosaic would tell a reader the areas are shares of a total when they are
a departure from an expectation.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRAssocplotLayerProcessor`

## Methods

### Public methods

- [`BaseRAssocplotLayerProcessor$process()`](#method-BaseRAssocplotLayerProcessor-process)

- [`BaseRAssocplotLayerProcessor$needs_reordering()`](#method-BaseRAssocplotLayerProcessor-needs_reordering)

- [`BaseRAssocplotLayerProcessor$extract_data()`](#method-BaseRAssocplotLayerProcessor-extract_data)

- [`BaseRAssocplotLayerProcessor$pearson_residuals()`](#method-BaseRAssocplotLayerProcessor-pearson_residuals)

- [`BaseRAssocplotLayerProcessor$recorded_table()`](#method-BaseRAssocplotLayerProcessor-recorded_table)

- [`BaseRAssocplotLayerProcessor$extract_axis_titles()`](#method-BaseRAssocplotLayerProcessor-extract_axis_titles)

- [`BaseRAssocplotLayerProcessor$extract_main_title()`](#method-BaseRAssocplotLayerProcessor-extract_main_title)

- [`BaseRAssocplotLayerProcessor$generate_selectors()`](#method-BaseRAssocplotLayerProcessor-generate_selectors)

- [`BaseRAssocplotLayerProcessor$clone()`](#method-BaseRAssocplotLayerProcessor-clone)

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

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$process()`

Process the association plot layer.

#### Usage

    BaseRAssocplotLayerProcessor$process(
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

### `BaseRAssocplotLayerProcessor$needs_reordering()`

#### Usage

    BaseRAssocplotLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$extract_data()`

Read the residual grid out of the recorded call.

The grid is the table **transposed**, and its rows reversed. That is not
a convention chosen here but the relation
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has to
its argument, measured from the drawn rects: the first dimension runs
across the x axis and the second up the y axis, bottom to top. It is the
same relation
[`image()`](https://r.maidr.ai/reference/base-r-wrappers.md) has to its
matrix, and the heatmap processor transposes for the same reason.

A table with a zero margin has cells whose expected count is zero, and a
residual there is `0/0`.
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
nothing for such a cell; the grid has to keep a place for it, so it
carries 0 – the departure from an expectation of nothing being nothing.

#### Usage

    BaseRAssocplotLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

List with points, x and y, empty when there is no table

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$pearson_residuals()`

The Pearson residual of every cell.

`(observed - expected) / sqrt(expected)`, with the expected counts taken
from the margins the same way
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes
them.

#### Usage

    BaseRAssocplotLayerProcessor$pearson_residuals(table)

#### Arguments

- `table`:

  A two-way table

#### Returns

A numeric matrix of the same shape

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$recorded_table()`

The two-way table the call was handed, when it is one.

Only a two-dimensional table is read.
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) itself
accepts no more – it stops on anything else – so this declines the same
inputs the function does.

#### Usage

    BaseRAssocplotLayerProcessor$recorded_table(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

A 2-D table, or NULL

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$extract_axis_titles()`

Name the axes from the table's own dimension names.

[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) labels
its axes with `names(dimnames(x))` unless the author overrides them, so
those are the words a reader should be given. `z` names what the numbers
are rather than a dimension of the table: the grid holds residuals, and
a reader told "Eye" for the value would be told a level name where a
number is.

#### Usage

    BaseRAssocplotLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$extract_main_title()`

The title the call was given, if any.

#### Usage

    BaseRAssocplotLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Character scalar, empty when the author wrote no title

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$generate_selectors()`

Address the tiles the chart drew.

[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
every cell into ONE rect grob – measured, a 4x4 table gives
`graphics-plot-N-rect-1` holding sixteen rects – so the cells need no
picking out of the drawing the way a gantt's bars do.

#### Usage

    BaseRAssocplotLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `layer_info`:

  Information about the recorded plot call

- `gt`:

  Gtable object (optional)

- `extracted_data`:

  The grid this layer emitted

#### Returns

List of selectors, one per cell

------------------------------------------------------------------------

### `BaseRAssocplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRAssocplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
