# Point Layer Processor

Processes scatter plot layers (geom_point) to extract point data and
generate selectors for individual points in the SVG structure.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2PointLayerProcessor`

## Methods

### Public methods

- [`Ggplot2PointLayerProcessor$process()`](#method-Ggplot2PointLayerProcessor-process)

- [`Ggplot2PointLayerProcessor$colour_group_layers()`](#method-Ggplot2PointLayerProcessor-colour_group_layers)

- [`Ggplot2PointLayerProcessor$extract_axes_labels()`](#method-Ggplot2PointLayerProcessor-extract_axes_labels)

- [`Ggplot2PointLayerProcessor$extract_axis_grid_info()`](#method-Ggplot2PointLayerProcessor-extract_axis_grid_info)

- [`Ggplot2PointLayerProcessor$extract_data()`](#method-Ggplot2PointLayerProcessor-extract_data)

- [`Ggplot2PointLayerProcessor$generate_selectors()`](#method-Ggplot2PointLayerProcessor-generate_selectors)

- [`Ggplot2PointLayerProcessor$find_panel_grob()`](#method-Ggplot2PointLayerProcessor-find_panel_grob)

- [`Ggplot2PointLayerProcessor$find_children_by_type()`](#method-Ggplot2PointLayerProcessor-find_children_by_type)

- [`Ggplot2PointLayerProcessor$clone()`](#method-Ggplot2PointLayerProcessor-clone)

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

### `Ggplot2PointLayerProcessor$process()`

Process the point layer

#### Usage

    Ggplot2PointLayerProcessor$process(
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

  Panel context for panel-scoped selector generation (optional)

#### Returns

List with data and selectors

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$colour_group_layers()`

One point layer per colour group, named as the legend names it

`aes(colour = group)` draws each group of points in its own colour and
names the colours in a legend. The layer was read as one cloud, each
point carrying the group in a `color` field maidr.js does not read, so a
reader never heard which group a point was in and could not walk one
group at a time. The groups are now layers of their own, as a grouped
lattice [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) and
py-maidr's hue scatters are read: in the order the legend lists them,
each named for its entry and the legend's title
([`group_layer_name()`](https://r.maidr.ai/reference/group_layer_name.md)),
and highlighted through its own points.

ggplot2 draws every point of the layer in one grob, in row order, and
the export numbers each `<use>` by its place in it. A group's points are
named by those numbers: a selector list matches in document order, which
is the order the group's points are emitted in.

A colour mapped to a continuous scale is a value, not a group, and is
left as it was; so is a layer in which any point has no group. Only a
plain
[`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
layer is split: a volcano or Manhattan layer, read through this
processor too, is one reading with its threshold, and its colour groups
are announced as each point's region.

#### Usage

    Ggplot2PointLayerProcessor$colour_group_layers(
      plot,
      built,
      points,
      selectors,
      axes
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `points`:

  The layer's points, from `extract_data()`

- `selectors`:

  The layer's selectors, from `generate_selectors()`

- `axes`:

  The layer's axes

#### Returns

A multi-layer result, or NULL when the layer is not grouped by colour
into two groups or more

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$extract_axes_labels()`

Extract axis information from the plot

Returns per-axis objects with label and optional grid navigation fields
(min, max, tickStep). Grid fields are only included when they can be
successfully extracted from the built plot scales.

Each label is the axis title unless the layer maps that axis itself and
another layer plots something else there (see
[`layer_axis_label()`](https://r.maidr.ai/reference/layer_axis_label.md)),
the rule every other layer follows.

#### Usage

    Ggplot2PointLayerProcessor$extract_axes_labels(
      plot,
      built = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List with x and y per-axis objects

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$extract_axis_grid_info()`

Extract grid navigation info (min, max, tickStep) for a single axis

Delegates to
[`axis_grid_info()`](https://r.maidr.ai/reference/axis_grid_info.md),
which is where the reading now lives: the rug processor needs the same
answer for the axis its ticks stand on, and one grid rule read two ways
is how the two would drift. Kept as a method so this class's own callers
are unchanged.

#### Usage

    Ggplot2PointLayerProcessor$extract_axis_grid_info(
      built,
      axis = "x",
      panel_id = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `axis`:

  Character, either "x" or "y"

- `panel_id`:

  Panel index for faceted plots (optional, defaults to 1)

#### Returns

List with min, max, tickStep or NULL if extraction fails

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$extract_data()`

Extract data from point layer

#### Usage

    Ggplot2PointLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List with points array and color information

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$generate_selectors()`

Generate selectors for point elements

#### Usage

    Ggplot2PointLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$find_panel_grob()`

Find the panel grob this layer draws into

#### Usage

    Ggplot2PointLayerProcessor$find_panel_grob(gt, panel_ctx = NULL)

#### Arguments

- `gt`:

  The gtable to search

- `panel_ctx`:

  Panel context for patchwork leaves and facets; NULL for a single plot,
  where the panel is the cell literally named "panel"

#### Returns

The panel grob or NULL

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$find_children_by_type()`

Find children by type pattern

#### Usage

    Ggplot2PointLayerProcessor$find_children_by_type(grob, type_pattern)

#### Arguments

- `grob`:

  The grob to search

- `type_pattern`:

  Pattern to match

#### Returns

List of matching children

------------------------------------------------------------------------

### `Ggplot2PointLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PointLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
