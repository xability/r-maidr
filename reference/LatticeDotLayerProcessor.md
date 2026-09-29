# lattice Dot Layer Processor

Reads a [`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) panel
that has at most one value per level – a Cleveland dot plot – as a `dot`
layer, which the frontend builds on its bar reading: one value per
category, walked along the axis. One layer per group, named after it.

The panel's rows were sorted by level before drawing
([`lattice_prepare()`](https://r.maidr.ai/reference/lattice_prepare.md)),
so the dots are drawn in the order the levels run along the axis, which
is the order the frontend pairs a bar-shaped layer's marks with its
values.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticeDotLayerProcessor`

## Methods

### Public methods

- [`LatticeDotLayerProcessor$process()`](#method-LatticeDotLayerProcessor-process)

- [`LatticeDotLayerProcessor$extract_data()`](#method-LatticeDotLayerProcessor-extract_data)

- [`LatticeDotLayerProcessor$clone()`](#method-LatticeDotLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_polyline_grob)
- [`LayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/LayerProcessor.html#method-generate_selectors)
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
- [`LatticeLayerProcessor$axis_values()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-axis_values)
- [`LatticeLayerProcessor$category_of()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-category_of)
- [`LatticeLayerProcessor$grob()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-grob)
- [`LatticeLayerProcessor$group_label()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-group_label)
- [`LatticeLayerProcessor$layer_axes()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-layer_axes)
- [`LatticeLayerProcessor$position_values()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-position_values)
- [`LatticeLayerProcessor$time_axes()`](https://r.maidr.ai/reference/LatticeLayerProcessor.html#method-time_axes)

------------------------------------------------------------------------

### `LatticeDotLayerProcessor$process()`

Read the layer

#### Usage

    LatticeDotLayerProcessor$process(
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

  The trellis object

- `layout`:

  The figure's layout: title and axis labels

- `built`:

  Unused for lattice

- `gt`:

  The drawn chart

- `grob_id`:

  Unused for lattice

- `panel_id`:

  Unused for lattice

- `panel_ctx`:

  The panel the layer was drawn in

- `layer_info`:

  The layer: its type, role and grobs

#### Returns

The layer, or NULL when its marks cannot be read

------------------------------------------------------------------------

### `LatticeDotLayerProcessor$extract_data()`

Read the drawn dots

#### Usage

    LatticeDotLayerProcessor$extract_data(plot, panel_ctx, grob, horizontal)

#### Arguments

- `plot`:

  The trellis object

- `panel_ctx`:

  The panel

- `grob`:

  The points grob

- `horizontal`:

  Whether the levels run up the vertical axis

#### Returns

List of `x`/`y` points – the value along the value axis and the level's
name – or NULL when the dots are not one per level in level order

------------------------------------------------------------------------

### `LatticeDotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeDotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
