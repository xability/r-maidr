# lattice Point Layer Processor

Reads the points an
[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html),
[`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html),
[`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) or
[`qq()`](https://rdrr.io/pkg/lattice/man/qq.html) panel draws, and a
[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) panel that
has several values on a level, as a `point` layer: one layer per group,
named after it.

The values are the drawn coordinates, which lattice draws in data units
(`default.units = "native"`), so a
[`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) layer reads
the quantiles the panel computed rather than the sample it was given. On
a factor axis a coordinate is the level's position; it is emitted as
that position with the level's name as `xLabel` or `yLabel`, which is
how the frontend reads a strip of points by category.

An axis the panel jittered – `xyplot(jitter.x = TRUE)`,
`stripplot(jitter.data = TRUE)` – is drawn at a random offset from each
value, a precise number for a quantity that does not exist and a
different one at every print; rounded back to a level, a point jittered
by more than half of one is named by the next. On such an axis the value
is read from the panel's own rows instead, which those panel functions
draw one point each, in order.

A date or date-time axis is emitted in milliseconds with a date format,
as the frontend reads a time
([`lattice_time_milliseconds()`](https://r.maidr.ai/reference/lattice_time_milliseconds.md)).

A point whose coordinates are missing is not drawn, and the exporter
skips it without renumbering the others, so it is left out here too: the
frontend pairs points with their marks by position only when the counts
agree.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticePointLayerProcessor`

## Methods

### Public methods

- [`LatticePointLayerProcessor$process()`](#method-LatticePointLayerProcessor-process)

- [`LatticePointLayerProcessor$extract_data()`](#method-LatticePointLayerProcessor-extract_data)

- [`LatticePointLayerProcessor$jittered_axes()`](#method-LatticePointLayerProcessor-jittered_axes)

- [`LatticePointLayerProcessor$point_axes()`](#method-LatticePointLayerProcessor-point_axes)

- [`LatticePointLayerProcessor$clone()`](#method-LatticePointLayerProcessor-clone)

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

### `LatticePointLayerProcessor$process()`

Read the layer

#### Usage

    LatticePointLayerProcessor$process(
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

### `LatticePointLayerProcessor$extract_data()`

Read the drawn points

#### Usage

    LatticePointLayerProcessor$extract_data(plot, panel_ctx, grob, entry = NULL)

#### Arguments

- `plot`:

  The trellis object

- `panel_ctx`:

  The panel

- `grob`:

  The points grob

- `entry`:

  The grob's entry, which says the group it was drawn for; without it a
  jittered axis is read as drawn

#### Returns

List of points, each `x`, `y` and a level name where an axis holds
categories

------------------------------------------------------------------------

### `LatticePointLayerProcessor$jittered_axes()`

The axes a panel drew its points on at a random offset

[`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html)
jitters x for `jitter.x = TRUE` and y for `jitter.y = TRUE`, and
[`panel.stripplot()`](https://rdrr.io/pkg/lattice/man/panel.stripplot.html)
its category axis for `jitter.data = TRUE`;
[`panel.dotplot()`](https://rdrr.io/pkg/lattice/man/panel.dotplot.html)
hands both flags on to
[`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html).
The other panel functions draw points that are not the panel's rows –
[`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html)'s quantiles –
and are read as drawn.

#### Usage

    LatticePointLayerProcessor$jittered_axes(plot, args)

#### Arguments

- `plot`:

  The trellis object

- `args`:

  The panel's arguments

#### Returns

Named logical `c(x = , y = )`

------------------------------------------------------------------------

### `LatticePointLayerProcessor$point_axes()`

The axes of a point layer, with their navigation grid

#### Usage

    LatticePointLayerProcessor$point_axes(plot, layout, panel_ctx)

#### Arguments

- `plot`:

  The trellis object

- `layout`:

  The figure's layout

- `panel_ctx`:

  The panel

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `LatticePointLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticePointLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
