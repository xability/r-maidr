# pheatmap Annotation Track Layer Processor

Reads one annotation track of a pheatmap – one variable of
`annotation_row` or `annotation_col`, found by
[`pheatmap_annotation_tracks()`](https://r.maidr.ai/reference/pheatmap_annotation_tracks.md)
– as a layer of the heat layer's own subplot, after it, named by the
variable (`name`).

**Shape.** Every track is one row of cells, one per column (a column
annotation) or per row (a row annotation) of the heat layer, in the
order the heat layer reads them, a row track's top first. Its `x` labels
are the heat layer's column or row labels, so switching layers from a
heat cell to a column track keeps the column.

- A numeric track is a `heat` layer of one row: `y` the variable's name,
  `points` its values, exactly; a value with no colour drawn is a hole.

- A categorical track is a `step` layer of one series, one point per
  cell: `x` its label, `y` the level's place among the levels (the order
  of `annotation_colors`, or else the factor's), and `label` the level,
  which maidr.js announces in place of `y`. A missing value is `y: null`
  with no `label`. maidr.js's `heat` cell is a number only, so a level
  can be announced only by a trace that carries a name beside its
  number.

The ComplexHeatmap reader emits its tracks in the same shape
(`ComplexHeatmapAnnotationLayerProcessor`, \#392).

**Selectors.** Each cell is the rect it is drawn as, in the grob named
[PHEATMAP_ANNOTATION_GROBS](https://r.maidr.ai/reference/PHEATMAP_ANNOTATION_GROBS.md):
for `heat`, a one-row grid; for `step`, one selector listing every cell,
which match in drawn order. A track whose rects are not one per value,
placed in drawn order, has none.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`PheatmapAnnotationLayerProcessor`

## Methods

### Public methods

- [`PheatmapAnnotationLayerProcessor$process()`](#method-PheatmapAnnotationLayerProcessor-process)

- [`PheatmapAnnotationLayerProcessor$extract_data()`](#method-PheatmapAnnotationLayerProcessor-extract_data)

- [`PheatmapAnnotationLayerProcessor$generate_selectors()`](#method-PheatmapAnnotationLayerProcessor-generate_selectors)

- [`PheatmapAnnotationLayerProcessor$clone()`](#method-PheatmapAnnotationLayerProcessor-clone)

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

### `PheatmapAnnotationLayerProcessor$process()`

Read the layer

#### Usage

    PheatmapAnnotationLayerProcessor$process(
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

  Unused

- `grob_id`:

  Unused

- `panel_id`:

  Unused

- `panel_ctx`:

  Unused

- `layer_info`:

  Unused; the track is the processor's `layer_info`

#### Returns

The layer

------------------------------------------------------------------------

### `PheatmapAnnotationLayerProcessor$extract_data()`

The track's cells, in the heat layer's order

#### Usage

    PheatmapAnnotationLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  Unused

- `built`:

  Unused

#### Returns

For `heat`, a list with `x`, `y` and `points`; for `step`, a list of one
series of points

------------------------------------------------------------------------

### `PheatmapAnnotationLayerProcessor$generate_selectors()`

The selectors of the track's cells

#### Usage

    PheatmapAnnotationLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  Unused

- `gt`:

  Unused

- `grob_id`:

  Unused

- `panel_ctx`:

  Unused

#### Returns

For `heat`, a one-row grid; for `step`, a list of one selector; NULL
when the cells cannot be selected

------------------------------------------------------------------------

### `PheatmapAnnotationLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    PheatmapAnnotationLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
