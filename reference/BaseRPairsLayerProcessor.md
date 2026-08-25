# Base R Scatterplot Matrix Processor

Reads [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the grid of scatters it draws: one panel per ordered pair of columns,
the column across plotted against the column down.

**A grid, not a layer.** Every other base R processor answers with one
layer, or several layers in one cell. A scatterplot matrix is `n x n`
*panels*, which is the figure's shape rather than a layer's, so this one
answers with `multi_panel = TRUE` and places each layer at its own cell.
That is the shape the same chart already gets elsewhere: `sns.pairplot`
in py-maidr, and a plotly `splom` since xability/py-maidr#667.

**The grid cannot come from the recording.** Measured,
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) sets its
own `par(mfrow)` internally and restores it, so nothing lands in the
device's layout calls –
[`get_layout_calls()`](https://r.maidr.ai/reference/get_layout_calls.md)
answers zero – and
[`detect_panel_configuration()`](https://r.maidr.ai/reference/detect_panel_configuration.md)
sees a single panel (#272). The grid is the reading's own, derived from
the number of columns.

**The panels are numbered column-major.** Measured against a real
`grid.echo()` export of a three-column matrix, gridGraphics writes nine
`graphics-plot-N` groups – one per cell, diagonal included – and pairing
them with a `panel` that recorded what it was handed gives

    k    cell     drawn
    1    (1,1)    text        the variable's name
    2    (2,1)    points      x = column 1, y = column 2
    3    (3,1)    points      x = column 1, y = column 3
    4    (1,2)    points      x = column 2, y = column 1
    5    (2,2)    text
    6    (3,2)    points      x = column 2, y = column 3
    7    (1,3)    points      x = column 3, y = column 1
    8    (2,3)    points      x = column 3, y = column 2
    9    (3,3)    text

– that is `k = (col - 1) * n + row`, and the panel at `(row, col)` plots
**column `col` horizontally against column `row` vertically**.

**The diagonal has no layer.** A diagonal cell draws the variable's name
and nothing else, which the orchestrator already has an answer for: a
cell with no layers becomes a valid empty subplot. Giving it a histogram
instead would announce a chart
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) does not
draw – its default `diag.panel` draws nothing at all.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRPointLayerProcessor`](https://r.maidr.ai/reference/BaseRPointLayerProcessor.md)
-\> `BaseRPairsLayerProcessor`

## Methods

### Public methods

- [`BaseRPairsLayerProcessor$process()`](#method-BaseRPairsLayerProcessor-process)

- [`BaseRPairsLayerProcessor$extract_columns()`](#method-BaseRPairsLayerProcessor-extract_columns)

- [`BaseRPairsLayerProcessor$column_names()`](#method-BaseRPairsLayerProcessor-column_names)

- [`BaseRPairsLayerProcessor$panel_layer()`](#method-BaseRPairsLayerProcessor-panel_layer)

- [`BaseRPairsLayerProcessor$panel_selectors()`](#method-BaseRPairsLayerProcessor-panel_selectors)

- [`BaseRPairsLayerProcessor$clone()`](#method-BaseRPairsLayerProcessor-clone)

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

### `BaseRPairsLayerProcessor$process()`

Emit one point layer per off-diagonal panel

#### Usage

    BaseRPairsLayerProcessor$process(
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

### `BaseRPairsLayerProcessor$extract_columns()`

The columns [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md)
drew, with the names it wrote

Read from the recorded call rather than re-derived. A formula call is
resolved from the frame the recording kept (#254) rather than from the
formula, whose variables may since have been rebound; the ordinary
spelling hands over a data frame or a matrix, which is recorded by value
and needs nothing.

An unnamed matrix is labelled the way `pairs.default` labels it –
measured against a real export, the diagonals of a two-column unnamed
matrix read "var 1" and "var 2".

A column that is not numeric is not a case to handle:
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) itself
stops with "non-numeric argument to 'pairs'" before anything is
recorded.

#### Usage

    BaseRPairsLayerProcessor$extract_columns(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call.

#### Returns

A named list of numeric vectors, empty when nothing resolves

------------------------------------------------------------------------

### `BaseRPairsLayerProcessor$column_names()`

The names [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md)
writes down its diagonal

#### Usage

    BaseRPairsLayerProcessor$column_names(handed, count)

#### Arguments

- `handed`:

  The recorded data frame or matrix.

- `count`:

  How many columns it has.

#### Returns

One name per column

------------------------------------------------------------------------

### `BaseRPairsLayerProcessor$panel_layer()`

One panel's points, axes and selector

A pair with a missing coordinate is dropped rather than announced.
Measured, [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md)
hands its panel the raw columns including `NA`, and
[`points()`](https://r.maidr.ai/reference/base-r-wrappers.md) then draws
nothing for that pair – so announcing it would offer a sample the chart
does not draw (#170).

#### Usage

    BaseRPairsLayerProcessor$panel_layer(columns, row, col, title)

#### Arguments

- `columns`:

  The named columns.

- `row`:

  Which column runs up the panel.

- `col`:

  Which column runs across it.

- `title`:

  The figure's own title.

#### Returns

A layer, or NULL when the panel drew no points

------------------------------------------------------------------------

### `BaseRPairsLayerProcessor$panel_selectors()`

The marks one panel was drawn into

Built rather than searched for, from the column-major numbering in the
class docs.
[`find_graphics_plot_grob()`](https://r.maidr.ai/reference/find_graphics_plot_grob.md)
answers with the first `points` grob of the plot, and a scatterplot
matrix draws one per cell, so a search would give every panel the first
cell's marks.

Numbered from one because a call that declares its own grid is the only
thing on the page:
[`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes over
the device's layout, and the orchestrator reads a grid from a single
call only.

#### Usage

    BaseRPairsLayerProcessor$panel_selectors(row, col, count)

#### Arguments

- `row`:

  Which column runs up the panel.

- `col`:

  Which column runs across it.

- `count`:

  How many columns there are.

#### Returns

A one-element list of selectors

------------------------------------------------------------------------

### `BaseRPairsLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPairsLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
