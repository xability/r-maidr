# Base R Directed Graph Layer Processor

Reads [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
directed igraph object – igraph's own `plot.igraph()` – as a directed
graph: one node per vertex, in vertex order, each naming the vertices
whose edges arrive at it, with its own attributes, read from the graph
rather than the drawing. Each node is outlined as its own circle:
`plot.igraph()` draws every circle vertex with one
[`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md) call, in
vertex order, and gridGraphics exports that call as one group of
`<circle>` elements.

Emitted with `type = "directed_graph"`, which the core has read since
maidr 4.14.0.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRDirectedGraphLayerProcessor`

## Methods

### Public methods

- [`BaseRDirectedGraphLayerProcessor$process()`](#method-BaseRDirectedGraphLayerProcessor-process)

- [`BaseRDirectedGraphLayerProcessor$needs_reordering()`](#method-BaseRDirectedGraphLayerProcessor-needs_reordering)

- [`BaseRDirectedGraphLayerProcessor$generate_selectors()`](#method-BaseRDirectedGraphLayerProcessor-generate_selectors)

- [`BaseRDirectedGraphLayerProcessor$clone()`](#method-BaseRDirectedGraphLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_data)
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

### `BaseRDirectedGraphLayerProcessor$process()`

Process the layer: the graph's nodes, one selector each

#### Usage

    BaseRDirectedGraphLayerProcessor$process(
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

  Unused; present for the processor interface

- `layout`:

  Unused; present for the processor interface

- `built`:

  Unused; present for the processor interface

- `gt`:

  Gtable of the replayed drawing, searched for selectors (optional)

- `grob_id`:

  Unused; present for the processor interface

- `panel_id`:

  Unused; present for the processor interface

- `panel_ctx`:

  Unused; present for the processor interface

- `layer_info`:

  Layer information with the recorded call

#### Returns

List describing the layer for the MAIDR payload

------------------------------------------------------------------------

### `BaseRDirectedGraphLayerProcessor$needs_reordering()`

Whether the plot data must be reordered; never

#### Usage

    BaseRDirectedGraphLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRDirectedGraphLayerProcessor$generate_selectors()`

One selector per node, each naming its own circle

#### Usage

    BaseRDirectedGraphLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      n_nodes = 0L
    )

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

- `n_nodes`:

  How many nodes the layer declares

#### Returns

A list of selectors, or an empty list when the circles cannot be found

------------------------------------------------------------------------

### `BaseRDirectedGraphLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRDirectedGraphLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
