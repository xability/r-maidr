# ComplexHeatmap Dendrogram Layer Processor

Reads the dendrograms a ComplexHeatmap heat map draws on one side, rows
or columns, as `tree` layers, from the `HeatmapList` its drawing
returned
([`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md));
see
[`complexheatmap_trees()`](https://r.maidr.ai/reference/complexheatmap_trees.md)
for which are read and
[`complexheatmap_tree_nodes()`](https://r.maidr.ai/reference/complexheatmap_tree_nodes.md)
for the nodes. Experimental.

Each leaf is named as the heat layer names its row or column
([ComplexHeatmapLayerProcessor](https://r.maidr.ai/reference/ComplexHeatmapLayerProcessor.md)),
in the same order.

**Selectors.** None. 'ComplexHeatmap' draws a dendrogram as segments,
several to a merge and nothing at a leaf, with no element per node; a
highlight that cannot be aligned with a node is left out rather than
placed on the wrong link.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`ComplexHeatmapTreeLayerProcessor`

## Methods

### Public methods

- [`ComplexHeatmapTreeLayerProcessor$process()`](#method-ComplexHeatmapTreeLayerProcessor-process)

- [`ComplexHeatmapTreeLayerProcessor$side()`](#method-ComplexHeatmapTreeLayerProcessor-side)

- [`ComplexHeatmapTreeLayerProcessor$drawn_side()`](#method-ComplexHeatmapTreeLayerProcessor-drawn_side)

- [`ComplexHeatmapTreeLayerProcessor$extract_data()`](#method-ComplexHeatmapTreeLayerProcessor-extract_data)

- [`ComplexHeatmapTreeLayerProcessor$generate_selectors()`](#method-ComplexHeatmapTreeLayerProcessor-generate_selectors)

- [`ComplexHeatmapTreeLayerProcessor$clone()`](#method-ComplexHeatmapTreeLayerProcessor-clone)

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

### `ComplexHeatmapTreeLayerProcessor$process()`

Read the layers

#### Usage

    ComplexHeatmapTreeLayerProcessor$process(
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

  Unused

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

  Unused; the side is the processor's `layer_info$side`

#### Returns

A list of `tree` layers, empty when the side has no drawn tree

------------------------------------------------------------------------

### `ComplexHeatmapTreeLayerProcessor$side()`

`"row"` or `"column"`

#### Usage

    ComplexHeatmapTreeLayerProcessor$side()

#### Returns

The side this processor reads

------------------------------------------------------------------------

### `ComplexHeatmapTreeLayerProcessor$drawn_side()`

Where the side's dendrograms are drawn

#### Usage

    ComplexHeatmapTreeLayerProcessor$drawn_side(gt)

#### Arguments

- `gt`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)

#### Returns

`"left"` or `"right"` for rows, `"top"` or `"bottom"` for columns

------------------------------------------------------------------------

### `ComplexHeatmapTreeLayerProcessor$extract_data()`

The trees drawn on the side

#### Usage

    ComplexHeatmapTreeLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The `Heatmap` or `HeatmapList` passed in

- `built`:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)

#### Returns

A list of `list(title, nodes)`, empty when none is drawn

------------------------------------------------------------------------

### `ComplexHeatmapTreeLayerProcessor$generate_selectors()`

No selectors; see the class description

#### Usage

    ComplexHeatmapTreeLayerProcessor$generate_selectors(
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

NULL

------------------------------------------------------------------------

### `ComplexHeatmapTreeLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ComplexHeatmapTreeLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
