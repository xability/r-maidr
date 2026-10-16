# pheatmap Heatmap Layer Processor

Reads the one `heat` layer of a pheatmap from its drawn gtable.

**Order.** [`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md)
reorders the matrix by its trees (`tree_row$order`, `tree_col$order`)
before drawing, and the gtable holds it in that order: the cells' fill
matrix, the row and column labels. Its rows are top first, as maidr.js
reads `data.points`.

**Values.** Each cell's value is, in order of preference:

- exact: the matrix
  [`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) – maidr's
  wrapper – kept with the chart (`"maidr_matrix"`), the matrix as drawn;

- otherwise the number printed in the cell, with `display_numbers`;

- otherwise the middle of the legend band the cell's colour stands for,
  rounded to the band's width – with the default 100 colours, to a
  hundredth of the range drawn.

[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
itself does not return its matrix, so a chart it drew directly has only
the last two. Neither is exact, and the layer's title says which was
used, as does a message (class `maidr_pheatmap_values`). A kept matrix
or printed numbers are used only when each value lies in the legend band
of its cell's colour, so numbers printed over the cells that are not
their values – p-values, say – are not read as them.

Every source is the matrix as drawn, so with `scale = "row"` or
`"column"` it is the scaled value (a z-score) the legend shows, not the
input, and with `kmeans_k` the cluster centres. A cell drawn in `na_col`
is a hole (`null`).

**Selectors.** The cells are one rect grob drawn column by column, each
column top to bottom. Each is selected by its own id, in a grid whose
rows run bottom first, as maidr.js's heat grid does.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`PheatmapHeatmapLayerProcessor`

## Methods

### Public methods

- [`PheatmapHeatmapLayerProcessor$process()`](#method-PheatmapHeatmapLayerProcessor-process)

- [`PheatmapHeatmapLayerProcessor$extract_data()`](#method-PheatmapHeatmapLayerProcessor-extract_data)

- [`PheatmapHeatmapLayerProcessor$labels()`](#method-PheatmapHeatmapLayerProcessor-labels)

- [`PheatmapHeatmapLayerProcessor$generate_selectors()`](#method-PheatmapHeatmapLayerProcessor-generate_selectors)

- [`PheatmapHeatmapLayerProcessor$clone()`](#method-PheatmapHeatmapLayerProcessor-clone)

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

### `PheatmapHeatmapLayerProcessor$process()`

Read the layer

#### Usage

    PheatmapHeatmapLayerProcessor$process(
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

  The pheatmap object

- `layout`:

  The figure's layout: its title

- `built`:

  Unused

- `gt`:

  The gtable, its cells named
  [PHEATMAP_CELLS_GROB](https://r.maidr.ai/reference/PHEATMAP_CELLS_GROB.md)

- `grob_id`:

  Unused

- `panel_id`:

  Unused

- `panel_ctx`:

  Unused

- `layer_info`:

  Unused

#### Returns

The layer, or NULL when its values cannot be read

------------------------------------------------------------------------

### `PheatmapHeatmapLayerProcessor$extract_data()`

The cells' values and labels, rows top first

#### Usage

    PheatmapHeatmapLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The pheatmap object

- `built`:

  The gtable, its cells named
  [PHEATMAP_CELLS_GROB](https://r.maidr.ai/reference/PHEATMAP_CELLS_GROB.md)

#### Returns

List with `x`, `y` and `points`, its `"source"` attribute `"matrix"`,
`"printed"` or `"legend"`; or NULL

------------------------------------------------------------------------

### `PheatmapHeatmapLayerProcessor$labels()`

The labels of one axis, in drawn order

The drawn labels when the axis shows them (`labels_row`, the k-means
clusters' names); else the matrix's dimnames; else, as for an unnamed
matrix, each row's or column's number in the input, in tree order.

#### Usage

    PheatmapHeatmapLayerProcessor$labels(gt, name, dimnames, tree, count)

#### Arguments

- `gt`:

  The gtable

- `name`:

  `"row_names"` or `"col_names"`

- `dimnames`:

  The fill matrix's names along the axis

- `tree`:

  The axis' `hclust`, or NA when it was not clustered

- `count`:

  The number of rows or columns drawn

#### Returns

Character vector

------------------------------------------------------------------------

### `PheatmapHeatmapLayerProcessor$generate_selectors()`

One selector per cell, rows bottom first

#### Usage

    PheatmapHeatmapLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The pheatmap object

- `gt`:

  The gtable, its cells named
  [PHEATMAP_CELLS_GROB](https://r.maidr.ai/reference/PHEATMAP_CELLS_GROB.md)

- `grob_id`:

  Unused

- `panel_ctx`:

  Unused

#### Returns

A grid of selectors, `[row][column]`

------------------------------------------------------------------------

### `PheatmapHeatmapLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    PheatmapHeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
