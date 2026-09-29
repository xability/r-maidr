# lattice Bar Layer Processor

Reads a [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html)
panel: a `bar` layer when it has no groups, and a `dodged_bar` or
`stacked_bar` layer – one series per group – when it has, as
`stack = FALSE` or `TRUE` draws them.

The values are the panel's data values, which the bars end at on the
value axis. They are not the bars' lengths: by default lattice draws a
bar from the edge of the panel rather than from zero.

`factor ~ numeric` draws the bars horizontally, the levels running up
the vertical axis, and the layer says so with `orientation = "horz"`,
each point holding the value in `x` and the level in `y`.

**Selectors.** An ungrouped panel draws one rectangle per row, in the
order of the rows, and those were sorted by level before drawing
([`lattice_prepare()`](https://r.maidr.ai/reference/lattice_prepare.md)),
so one selector pairs the bars with the levels in the order a reader
walks them. A grouped panel draws its bars in one grob per level – side
by side when dodged, split by sign when stacked, where a zero draws
nothing – so each bar is named by its own id, in a grid of series by
level with `null` where no bar was drawn, which the frontend reads in
payload order whatever the drawing order was.

A panel whose bars overlap – one level given two values, or a category
that is not a factor, which lattice turns into a shingle – cannot be
read as bars, and the chart falls back to an image.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticeBarLayerProcessor`

## Methods

### Public methods

- [`LatticeBarLayerProcessor$process()`](#method-LatticeBarLayerProcessor-process)

- [`LatticeBarLayerProcessor$read_bars()`](#method-LatticeBarLayerProcessor-read_bars)

- [`LatticeBarLayerProcessor$read_grouped_bars()`](#method-LatticeBarLayerProcessor-read_grouped_bars)

- [`LatticeBarLayerProcessor$clone()`](#method-LatticeBarLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_data)
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

### `LatticeBarLayerProcessor$process()`

Read the layer

#### Usage

    LatticeBarLayerProcessor$process(
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

### `LatticeBarLayerProcessor$read_bars()`

Read an ungrouped panel's bars

#### Usage

    LatticeBarLayerProcessor$read_bars(
      category,
      value,
      horizontal,
      panel_ctx,
      layer_info
    )

#### Arguments

- `category`:

  The panel's category factor

- `value`:

  The panel's values

- `horizontal`:

  Whether the levels run up the vertical axis

- `panel_ctx`:

  The panel

- `layer_info`:

  The layer

#### Returns

A list with `data` and `selectors`, or NULL when bars overlap or were
not drawn in level order

------------------------------------------------------------------------

### `LatticeBarLayerProcessor$read_grouped_bars()`

Read a grouped panel's bars as a grid of series by level

#### Usage

    LatticeBarLayerProcessor$read_grouped_bars(
      category,
      value,
      horizontal,
      panel_ctx,
      layer_info
    )

#### Arguments

- `category`:

  The panel's category factor

- `value`:

  The panel's values

- `horizontal`:

  Whether the levels run up the vertical axis

- `panel_ctx`:

  The panel

- `layer_info`:

  The layer

#### Returns

A list with `data` and `selectors`, or NULL when two bars share a cell

------------------------------------------------------------------------

### `LatticeBarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
