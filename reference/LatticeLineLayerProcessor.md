# lattice Line Layer Processor

Reads the lines an
[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) panel draws –
`type = "l"`, `"b"`, `"o"`, the average line of `"a"` – and a
[`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) panel's, as a
`line` layer with one series per group; and the staircase of
`type = "s"` or `"S"` as a `step` layer.

A line is read in the order it was drawn, which for lattice is the order
of the data:
[`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html)
joins the points as they come, so unsorted x draws a zigzag, and reading
it sorted would describe a line the chart does not show. A missing y
breaks the drawn line and is emitted as a gap (`y: null`) at its x. A
row with no x breaks it too, but has no position a gap could be put at –
the frontend places a line's points by their x, a number or a string –
and is left out, as py-maidr leaves out the matplotlib points with no x:
the pieces on either side are read as one. A value with a break on both
sides, such as one between two missing values, is drawn as nothing at
all, and is emitted as a gap as well
([`lattice_line_alone()`](https://r.maidr.ai/reference/lattice_line_alone.md)).

A staircase is drawn through `2n - 1` vertices for `n` samples, sorted
by x; the samples are the odd vertices, and `stepDirection` says which
way each riser runs: `"hv"` for `"s"`, `"vh"` for `"S"`. A missing value
breaks the staircase into pieces, and maidr.js 4.11.0 outlines most
samples of a staircase drawn in pieces at a corner rather than at the
sample; what is read is right, only the outline is not. With
`distribute.type = TRUE` that is the type of the layer's own groups,
which the adapter keeps apart by direction, not of the chart's `type`
vector as a whole.

A line on a factor axis runs through the levels' positions: its x is the
level's name, and on a factor y axis the name goes with the position as
`label`, since the frontend sonifies y and needs it a number. A date or
date-time axis is emitted in milliseconds with a date format, as the
frontend reads a time
([`lattice_time_milliseconds()`](https://r.maidr.ai/reference/lattice_time_milliseconds.md)).

A panel drawn with `horizontal = TRUE` – the default of
[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) and of
`stripplot(factor ~ numeric)` – runs its levels up the y axis and its
values along x, and a line there is a value per level:
[`panel.average()`](https://rdrr.io/pkg/lattice/man/panel.functions.html)
averages x within each y level, and a dot plot's line joins a group's
dots level by level. The frontend walks a line along its x and sonifies
and brailles its y, so that line is read as its vertical transpose is: x
is the level's name and y the value. Read as drawn, y would be the
level's position, `1..n` whatever the values, and groups whose values
differ would share no x for Up and Down to compare them at. A staircase
is left as drawn.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticeLineLayerProcessor`

## Methods

### Public methods

- [`LatticeLineLayerProcessor$process()`](#method-LatticeLineLayerProcessor-process)

- [`LatticeLineLayerProcessor$extract_series()`](#method-LatticeLineLayerProcessor-extract_series)

- [`LatticeLineLayerProcessor$runs_across_levels()`](#method-LatticeLineLayerProcessor-runs_across_levels)

- [`LatticeLineLayerProcessor$extract_across_levels()`](#method-LatticeLineLayerProcessor-extract_across_levels)

- [`LatticeLineLayerProcessor$clone()`](#method-LatticeLineLayerProcessor-clone)

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

### `LatticeLineLayerProcessor$process()`

Read the layer

#### Usage

    LatticeLineLayerProcessor$process(
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

### `LatticeLineLayerProcessor$extract_series()`

Read one drawn line as a series of points

#### Usage

    LatticeLineLayerProcessor$extract_series(plot, panel_ctx, grob, step = FALSE)

#### Arguments

- `plot`:

  The trellis object

- `panel_ctx`:

  The panel

- `grob`:

  The lines grob

- `step`:

  Whether the line is a staircase

#### Returns

List of points

------------------------------------------------------------------------

### `LatticeLineLayerProcessor$runs_across_levels()`

Whether the panel's lines run through levels up the y axis

#### Usage

    LatticeLineLayerProcessor$runs_across_levels(panel_ctx)

#### Arguments

- `panel_ctx`:

  The panel

#### Returns

TRUE when the panel is drawn with `horizontal = TRUE`, its y axis a
factor and its x axis not

------------------------------------------------------------------------

### `LatticeLineLayerProcessor$extract_across_levels()`

Read a line through the levels up the y axis, transposed

The level a vertex is drawn at is its position, and a vertex drawn at no
level has none. A missing value breaks the drawn line and is emitted as
a gap (`y: null`) at its level, as is a value drawn as nothing
([`lattice_line_alone()`](https://r.maidr.ai/reference/lattice_line_alone.md)).

#### Usage

    LatticeLineLayerProcessor$extract_across_levels(plot, panel_ctx, grob)

#### Arguments

- `plot`:

  The trellis object

- `panel_ctx`:

  The panel

- `grob`:

  The lines grob

#### Returns

List of points: `x` the level's name, `y` the value

------------------------------------------------------------------------

### `LatticeLineLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeLineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
