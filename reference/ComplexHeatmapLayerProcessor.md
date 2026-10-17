# ComplexHeatmap Heatmap Layer Processor

Reads the `heat` layer of one ComplexHeatmap heat map from the
`HeatmapList` its drawing returned
([`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)):
the one heat map of a chart, or one of a list's.

**Order.** The rows and columns are read in the order drawn, the heat
map's own row and column order in the drawn list: by the dendrograms
when clustered, by `row_order`/`column_order` when given, and in a list
by the order the list shares – the main heat map's rows in a horizontal
list, its columns in a vertical one. Rows are top first, as maidr.js
reads `data.points`.

**Splits.** A heat map split into slices (`row_split`, `row_km`,
`column_split`, `column_km`) is read as one grid, its slices put side by
side in the order drawn, top to bottom and left to right. The gaps
between slices are not cells, and are not read: moving past the last row
of one slice reaches the first row of the next.

**Values.** Each cell is the value of the heat map's own matrix (the
`matrix` slot), exactly; a missing or infinite value is a hole (`null`).
A value the colour mapping clips is still its own value, not the end of
the scale.

**Labels.** The row and column labels drawn (`row_labels`,
`column_labels`, which default to the matrix's dimnames); when the names
are not shown (`show_row_names = FALSE`), the matrix's dimnames; and for
an unnamed matrix, each row's or column's number in the matrix.

**Selectors.** Each cell is selected by its own id, in a grid whose rows
run bottom first, as maidr.js's heat grid does. When the body was drawn
as a raster image there are no cells to select, and the layer is read
without highlighting; a message (class `maidr_complexheatmap_raster`)
says so.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`ComplexHeatmapLayerProcessor`

## Methods

### Public methods

- [`ComplexHeatmapLayerProcessor$process()`](#method-ComplexHeatmapLayerProcessor-process)

- [`ComplexHeatmapLayerProcessor$extract_data()`](#method-ComplexHeatmapLayerProcessor-extract_data)

- [`ComplexHeatmapLayerProcessor$labels()`](#method-ComplexHeatmapLayerProcessor-labels)

- [`ComplexHeatmapLayerProcessor$generate_selectors()`](#method-ComplexHeatmapLayerProcessor-generate_selectors)

- [`ComplexHeatmapLayerProcessor$clone()`](#method-ComplexHeatmapLayerProcessor-clone)

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

------------------------------------------------------------------------

### `ComplexHeatmapLayerProcessor$process()`

Read the layer

#### Usage

    ComplexHeatmapLayerProcessor$process(
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

  The `Heatmap` or `HeatmapList` passed in

- `layout`:

  The layer's title and its rows' title

- `built`:

  Unused

- `gt`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md),
  its `heatmap` and `cells` those of the heat map read

- `grob_id`:

  Unused

- `panel_id`:

  Unused

- `panel_ctx`:

  Unused

- `layer_info`:

  Unused

#### Returns

The layer

------------------------------------------------------------------------

### `ComplexHeatmapLayerProcessor$extract_data()`

The cells' values and labels, rows top first

#### Usage

    ComplexHeatmapLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The `Heatmap` or `HeatmapList` passed in

- `built`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)

#### Returns

List with `x`, `y` and `points`

------------------------------------------------------------------------

### `ComplexHeatmapLayerProcessor$labels()`

The labels of one axis, in drawn order

#### Usage

    ComplexHeatmapLayerProcessor$labels(param, dimnames, order)

#### Arguments

- `param`:

  The heat map's `row_names_param` or `column_names_param`

- `dimnames`:

  The matrix's names along the axis, or NULL

- `order`:

  The rows or columns drawn, as indices into the matrix

#### Returns

Character vector

------------------------------------------------------------------------

### `ComplexHeatmapLayerProcessor$generate_selectors()`

One selector per cell, rows bottom first

#### Usage

    ComplexHeatmapLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The `Heatmap` or `HeatmapList` passed in

- `gt`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)

- `grob_id`:

  Unused

- `panel_ctx`:

  Unused

#### Returns

A grid of selectors, `[row][column]`, or an empty list when the cells
cannot be selected

------------------------------------------------------------------------

### `ComplexHeatmapLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ComplexHeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
