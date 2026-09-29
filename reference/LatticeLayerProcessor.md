# lattice Layer Processor

Base class for the processors that read a layer of a lattice panel. A
processor is handed the trellis object, the panel it reads (`panel_ctx`)
and the grobs its layer was drawn as (`layer_info$grobs`), and answers
the layer as the orchestrator emits it – or `NULL` when its marks cannot
be read, which makes the whole chart fall back to an image.

A layer with nothing drawn in it – a group with no finite value – is
answered with empty `data`, and the orchestrator leaves it out.

`panel_ctx` carries `packet`, `column` and `row` (the layout cell
lattice drew the panel in), `args` (the panel's arguments, as its panel
function received them), `title`, the packet's `x_limits` and
`y_limits`, and the chart's `group_levels` and `group_title`.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`LatticeLayerProcessor`

## Methods

### Public methods

- [`LatticeLayerProcessor$process()`](#method-LatticeLayerProcessor-process)

- [`LatticeLayerProcessor$grob()`](#method-LatticeLayerProcessor-grob)

- [`LatticeLayerProcessor$group_label()`](#method-LatticeLayerProcessor-group_label)

- [`LatticeLayerProcessor$layer_axes()`](#method-LatticeLayerProcessor-layer_axes)

- [`LatticeLayerProcessor$axis_values()`](#method-LatticeLayerProcessor-axis_values)

- [`LatticeLayerProcessor$position_values()`](#method-LatticeLayerProcessor-position_values)

- [`LatticeLayerProcessor$time_axes()`](#method-LatticeLayerProcessor-time_axes)

- [`LatticeLayerProcessor$category_of()`](#method-LatticeLayerProcessor-category_of)

- [`LatticeLayerProcessor$clone()`](#method-LatticeLayerProcessor-clone)

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

------------------------------------------------------------------------

### `LatticeLayerProcessor$process()`

Read the layer

#### Usage

    LatticeLayerProcessor$process(
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

### `LatticeLayerProcessor$grob()`

The grob one of the layer's entries was drawn as

[`lattice_draw_scene()`](https://r.maidr.ai/reference/lattice_draw_scene.md)
grabs every grob lattice draws as a child of the scene, so the grob is
looked up by name among those first.
[`grid::getGrob()`](https://rdrr.io/r/grid/grid.get.html) walks the
children from the first, and a walk for every group's grob made reading
a chart quadratic in its number of groups; it is kept for a grob drawn
inside another.

#### Usage

    LatticeLayerProcessor$grob(gt, entry)

#### Arguments

- `gt`:

  The drawn chart

- `entry`:

  A grob entry of the layer

#### Returns

The grob, or NULL when the chart holds none of that name

------------------------------------------------------------------------

### `LatticeLayerProcessor$group_label()`

The name of the group a grob entry was drawn for

#### Usage

    LatticeLayerProcessor$group_label(panel_ctx, entry)

#### Arguments

- `panel_ctx`:

  The panel

- `entry`:

  A grob entry of the layer

#### Returns

A string, or NULL for an ungrouped entry

------------------------------------------------------------------------

### `LatticeLayerProcessor$layer_axes()`

The layer's axes, with the grouping variable as z

#### Usage

    LatticeLayerProcessor$layer_axes(layout, panel_ctx, grouped = FALSE)

#### Arguments

- `layout`:

  The figure's layout

- `panel_ctx`:

  The panel

- `grouped`:

  Whether the layer names its series or layers by group

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `LatticeLayerProcessor$axis_values()`

A drawn coordinate on the data's own scale

#### Usage

    LatticeLayerProcessor$axis_values(values, axis, plot)

#### Arguments

- `values`:

  Numeric values as lattice drew them

- `axis`:

  `"x"` or `"y"`

- `plot`:

  The trellis object

#### Returns

The values, back-transformed from a log scale

------------------------------------------------------------------------

### `LatticeLayerProcessor$position_values()`

A drawn coordinate as a point or a line carries it

`axis_values()`, and on a date or date-time axis the instant it stands
for, in milliseconds since 1970 (see
[`lattice_time_milliseconds()`](https://r.maidr.ai/reference/lattice_time_milliseconds.md));
a processor that emits it so gives the layer's axes the time format with
`time_axes()`.

#### Usage

    LatticeLayerProcessor$position_values(values, axis, plot, panel_ctx)

#### Arguments

- `values`:

  Numeric values as lattice drew them

- `axis`:

  `"x"` or `"y"`

- `plot`:

  The trellis object

- `panel_ctx`:

  The panel

#### Returns

Numeric values

------------------------------------------------------------------------

### `LatticeLayerProcessor$time_axes()`

Axes with the format of each time axis attached

The format that announces the milliseconds `position_values()` emits on
a date or date-time axis as the date they stand for, and, on a time
series' time axis, the decimals that keep its observations apart
([`lattice_series_time_format()`](https://r.maidr.ai/reference/lattice_series_time_format.md)).

#### Usage

    LatticeLayerProcessor$time_axes(axes, panel_ctx)

#### Arguments

- `axes`:

  Canonical axes list

- `panel_ctx`:

  The panel

#### Returns

The axes

------------------------------------------------------------------------

### `LatticeLayerProcessor$category_of()`

The category a drawn coordinate on a factor axis stands for

lattice draws a factor at its level's position, `1..nlevels`, and
[`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) jitters it
by less than half a position.

#### Usage

    LatticeLayerProcessor$category_of(values, limits)

#### Arguments

- `values`:

  Numeric positions as lattice drew them

- `limits`:

  The packet's limits on that axis: the level names

#### Returns

A list with the integer `position` and the level `label`

------------------------------------------------------------------------

### `LatticeLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
