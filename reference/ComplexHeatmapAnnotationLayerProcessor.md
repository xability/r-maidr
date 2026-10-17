# ComplexHeatmap Annotation Layer Processor

Reads one simple annotation track of a ComplexHeatmap heat map
([`complexheatmap_annotation_tracks()`](https://r.maidr.ai/reference/complexheatmap_annotation_tracks.md))
as a layer of the heat map's subplot, beside its `heat` layer, named by
the annotation (`name`).

**Shape.** Every track is read as a row of its own, one cell per column
(a column annotation) or per row (a row annotation) of the heat layer,
in the order the heat layer reads them: clustered, reordered and split
as drawn, a row track top first. Its `x` labels are the heat layer's
column or row labels, so moving between the heat layer and a column
track keeps the column.

- A track mapped to a continuous colour scale is a 1-row `heat` layer:
  `y` is the track's name, `points` its values, exactly; a missing value
  is a hole (`null`).

- A track mapped to discrete colours (characters, factors, logicals, or
  numbers given discrete colours) is a `step` layer of one series, one
  point per cell: `x` its label, `y` the level's place among the colour
  mapping's levels (1, 2, ...), and `label` the level, which maidr.js
  announces in place of `y`. A missing value is `y: null` without a
  `label`. maidr.js's `heat` cell is a number only, so a level can be
  announced only by a trace that carries a name beside its number.

**Selectors.** Each cell is the rect it is drawn as
([`complexheatmap_name_annotations()`](https://r.maidr.ai/reference/complexheatmap_name_annotations.md)):
for `heat`, a one-row grid; for `step`, one selector matching every cell
in drawn order. A track whose cells cannot be told apart is read without
highlighting.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`ComplexHeatmapAnnotationLayerProcessor`

## Methods

### Public methods

- [`ComplexHeatmapAnnotationLayerProcessor$process()`](#method-ComplexHeatmapAnnotationLayerProcessor-process)

- [`ComplexHeatmapAnnotationLayerProcessor$is_categorical()`](#method-ComplexHeatmapAnnotationLayerProcessor-is_categorical)

- [`ComplexHeatmapAnnotationLayerProcessor$extract_data()`](#method-ComplexHeatmapAnnotationLayerProcessor-extract_data)

- [`ComplexHeatmapAnnotationLayerProcessor$generate_selectors()`](#method-ComplexHeatmapAnnotationLayerProcessor-generate_selectors)

- [`ComplexHeatmapAnnotationLayerProcessor$clone()`](#method-ComplexHeatmapAnnotationLayerProcessor-clone)

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

### `ComplexHeatmapAnnotationLayerProcessor$process()`

Read the layer

#### Usage

    ComplexHeatmapAnnotationLayerProcessor$process(
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

  The figure's layout: its title and its rows' title

- `built`:

  Unused

- `gt`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)

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

### `ComplexHeatmapAnnotationLayerProcessor$is_categorical()`

Whether the track's colours are discrete levels

#### Usage

    ComplexHeatmapAnnotationLayerProcessor$is_categorical()

#### Returns

Logical

------------------------------------------------------------------------

### `ComplexHeatmapAnnotationLayerProcessor$extract_data()`

The track's cells, in the heat layer's order

#### Usage

    ComplexHeatmapAnnotationLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The `Heatmap` or `HeatmapList` passed in

- `built`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)

#### Returns

For `heat`, a list with `x`, `y` and `points`; for `step`, a list of one
series of points

------------------------------------------------------------------------

### `ComplexHeatmapAnnotationLayerProcessor$generate_selectors()`

The selectors of the track's cells

#### Usage

    ComplexHeatmapAnnotationLayerProcessor$generate_selectors(
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

For `heat`, a one-row grid; for `step`, a list of one selector; an empty
list when the cells cannot be selected

------------------------------------------------------------------------

### `ComplexHeatmapAnnotationLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ComplexHeatmapAnnotationLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
