# Directed Graph Layer Processor

Reads the nodes of a
[`ggraph::ggraph()`](https://ggraph.data-imaginist.com/reference/ggraph.html)
drawing of a directed graph as the `directed_graph` trace: one node per
drawn point, each naming the nodes whose edges arrive at it, so a reader
walks the graph by its edges – what feeds a node, what it feeds, where
the graph branches and merges.

A ggraph chart is an edge layer (`geom_edge_link()` and its siblings,
ggraph's own geoms), a node layer (`geom_node_point()`, a `GeomPoint`
over the node layout) and labels. The edge geoms matched no branch of
the adapter, and an unread layer drops the whole chart to a static
image; read as points, the nodes would say only where the layout put
them. So for a directed graph the edge layers are skipped and the node
layer carries the graph, read from the `igraph` object ggraph keeps on
the layout.

Each node is highlighted as its own point: the node layer draws one
point per node, in node order, as one group of `<use>` elements.

Emitted with `type = "directed_graph"`, which the core has read since
maidr 4.14.0.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2PointLayerProcessor`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.md)
-\> `Ggplot2DirectedGraphLayerProcessor`

## Methods

### Public methods

- [`Ggplot2DirectedGraphLayerProcessor$process()`](#method-Ggplot2DirectedGraphLayerProcessor-process)

- [`Ggplot2DirectedGraphLayerProcessor$node_selectors()`](#method-Ggplot2DirectedGraphLayerProcessor-node_selectors)

- [`Ggplot2DirectedGraphLayerProcessor$clone()`](#method-Ggplot2DirectedGraphLayerProcessor-clone)

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
- [`Ggplot2PointLayerProcessor$extract_axes_labels()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axes_labels)
- [`Ggplot2PointLayerProcessor$extract_axis_grid_info()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axis_grid_info)
- [`Ggplot2PointLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_data)
- [`Ggplot2PointLayerProcessor$find_children_by_type()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_children_by_type)
- [`Ggplot2PointLayerProcessor$find_panel_grob()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_panel_grob)
- [`Ggplot2PointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-generate_selectors)

------------------------------------------------------------------------

### `Ggplot2DirectedGraphLayerProcessor$process()`

Process the node layer

#### Usage

    Ggplot2DirectedGraphLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data, selectors, title, axes and type

------------------------------------------------------------------------

### `Ggplot2DirectedGraphLayerProcessor$node_selectors()`

One selector per node, each naming its own point

The point processor names the layer's point group, `> use` matching
every point in it; the n-th `<use>` is the n-th node.

#### Usage

    Ggplot2DirectedGraphLayerProcessor$node_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL,
      n_nodes = 0L
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

- `n_nodes`:

  How many nodes the layer declares

#### Returns

A list of selectors, or an empty list

------------------------------------------------------------------------

### `Ggplot2DirectedGraphLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2DirectedGraphLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
