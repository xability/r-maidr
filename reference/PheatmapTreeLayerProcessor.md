# pheatmap Dendrogram Layer Processor

Reads one of a pheatmap's dendrograms as a `tree` layer, from the
`hclust` it was drawn from (`tree_row` or `tree_col`); see
[`pheatmap_tree_nodes()`](https://r.maidr.ai/reference/pheatmap_tree_nodes.md)
for the nodes. Experimental.

A side has a tree only when it was clustered and the tree is drawn: not
with `cluster_rows = FALSE`, nor with `treeheight_row = 0`, which orders
the rows by the tree but draws none. With `kmeans_k` the row tree is the
one pheatmap draws, over the cluster centres. `cutree_rows` only spaces
the drawing; the tree is unchanged.

Each leaf is named as the heat layer names its row or column
([`pheatmap_axis_labels()`](https://r.maidr.ai/reference/pheatmap_axis_labels.md)),
in the same order.

**Selectors.** None. pheatmap draws a dendrogram as one polyline per
merge – `n - 1` marks for `2n - 1` nodes, nothing at a leaf – and the
trace needs one element per node, in node order; a highlight that cannot
be aligned is left out rather than placed on the wrong link.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`PheatmapTreeLayerProcessor`

## Methods

### Public methods

- [`PheatmapTreeLayerProcessor$process()`](#method-PheatmapTreeLayerProcessor-process)

- [`PheatmapTreeLayerProcessor$side()`](#method-PheatmapTreeLayerProcessor-side)

- [`PheatmapTreeLayerProcessor$extract_data()`](#method-PheatmapTreeLayerProcessor-extract_data)

- [`PheatmapTreeLayerProcessor$generate_selectors()`](#method-PheatmapTreeLayerProcessor-generate_selectors)

- [`PheatmapTreeLayerProcessor$clone()`](#method-PheatmapTreeLayerProcessor-clone)

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

### `PheatmapTreeLayerProcessor$process()`

Read the layer

#### Usage

    PheatmapTreeLayerProcessor$process(
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

  Unused

- `built`:

  Unused

- `gt`:

  The gtable

- `grob_id`:

  Unused

- `panel_id`:

  Unused

- `panel_ctx`:

  Unused

- `layer_info`:

  Unused; the side is the processor's `layer_info$side`

#### Returns

The layer, or NULL when that side has no drawn tree

------------------------------------------------------------------------

### `PheatmapTreeLayerProcessor$side()`

`"row"` or `"col"`

#### Usage

    PheatmapTreeLayerProcessor$side()

#### Returns

The side this processor reads

------------------------------------------------------------------------

### `PheatmapTreeLayerProcessor$extract_data()`

The tree's nodes

#### Usage

    PheatmapTreeLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The pheatmap object

- `built`:

  The gtable

#### Returns

A list of nodes, empty when the side has no drawn tree

------------------------------------------------------------------------

### `PheatmapTreeLayerProcessor$generate_selectors()`

No selectors; see the class description

#### Usage

    PheatmapTreeLayerProcessor$generate_selectors(
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

### `PheatmapTreeLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    PheatmapTreeLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
