# Polygon Layer Processor

Reads
[`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
as the closed path it draws.

A polygon is
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
with its ends joined and its interior filled. `GeomPath` has been
dispatched to `"line"` since before this file existed, so reading a
polygon the same way decides nothing new about what a series of vertices
means – it makes two spellings of one mark behave alike, the argument
`GeomSpoke` was routed through `GeomSegment` on (#225).

What it was costing until then is the whole chart. `"unknown"` is what
makes `has_unsupported_layers()` true and drops the plot to a static
image (#176). Measured on ggplot2 3.4.4, thirty points,
[`save_html()`](https://r.maidr.ai/reference/save_html.md):

    geom_point()                     interactive SVG   52,708 bytes
    geom_point() + geom_polygon()    base64 image      30,913 bytes
    geom_polygon() alone             base64 image      18,353 bytes

Skipping it instead was declined in \#225 and the reason is worth
keeping here: every geom skipped today carries no observations –
[`geom_blank()`](https://ggplot2.tidyverse.org/reference/geom_blank.html)
draws nothing, a reference line is a constant, a text label repeats a
value already in the payload – so skipping loses a reader nothing they
could have navigated. A polygon's vertices are rows the author supplied.
Skipping one that is the data would drop it silently, which is worse
than the honest picture, because the reader is not told anything is
missing.

### The closing vertex is not emitted

Four rows draw a quadrilateral with four corners and five edges. The
fifth edge is the closure, and it adds no observation – which is
ggplot2's own reading as well: `GeomPolygon$draw_panel()` hands grid the
munched rows unchanged under a linear coord, and the drawn element holds
exactly as many points as the layer has rows. Straight off the exported
SVG for `x = c(1, 3, 3, 1)`, `y = c(1, 1, 3, 3)`:

    <polygon points="49.84,53.12 171.93,53.12 171.93,265.22 49.84,265.22"/>

So a series and its drawn shape are the same length, in the same order,
and a reader who navigates to the end has been told every vertex once.

### Addressing

Unlike a line, a polygon layer names its grob after its geom, so it
needs no draw-order search of anonymous `GRID.polyline.N` grobs. gridSVG
turns one grob into one element per **group**, which is the granularity
the multi-series trace wants:

    <g id="geom_polygon.polygon.57.1">
      <polygon id="geom_polygon.polygon.57.1.1"/>   <- group 1
      <polygon id="geom_polygon.polygon.57.1.2"/>   <- group 2

`aes(subgroup =)` – a shape with a hole in it – is drawn as a `pathgrob`
rather than a `polygon`, and gridSVG still emits one `<path>` per
`pathId`, which is still the group. Measured on two groups of two
subgroups: `geom_polygon.pathgrob.42.1.1` and `...1.2`, each holding
both of its rings in one `d`. So both spellings address the same way and
only the element differs, which is why the search below matches either.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\> `Ggplot2PolygonLayerProcessor`

## Methods

### Public methods

- [`Ggplot2PolygonLayerProcessor$process()`](#method-Ggplot2PolygonLayerProcessor-process)

- [`Ggplot2PolygonLayerProcessor$resolve_group_mapping()`](#method-Ggplot2PolygonLayerProcessor-resolve_group_mapping)

- [`Ggplot2PolygonLayerProcessor$attach_group_axis()`](#method-Ggplot2PolygonLayerProcessor-attach_group_axis)

- [`Ggplot2PolygonLayerProcessor$group_aes()`](#method-Ggplot2PolygonLayerProcessor-group_aes)

- [`Ggplot2PolygonLayerProcessor$curve_selectors()`](#method-Ggplot2PolygonLayerProcessor-curve_selectors)

- [`Ggplot2PolygonLayerProcessor$polygon_shape_count()`](#method-Ggplot2PolygonLayerProcessor-polygon_shape_count)

- [`Ggplot2PolygonLayerProcessor$find_layer_polygon_grob()`](#method-Ggplot2PolygonLayerProcessor-find_layer_polygon_grob)

- [`Ggplot2PolygonLayerProcessor$layer_polygon_grobs()`](#method-Ggplot2PolygonLayerProcessor-layer_polygon_grobs)

- [`Ggplot2PolygonLayerProcessor$polygon_layer_position()`](#method-Ggplot2PolygonLayerProcessor-polygon_layer_position)

- [`Ggplot2PolygonLayerProcessor$clone()`](#method-Ggplot2PolygonLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
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
- [`Ggplot2LineLayerProcessor$attach_discrete_y_names()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_discrete_y_names)
- [`Ggplot2LineLayerProcessor$attach_level_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_level_labels)
- [`Ggplot2LineLayerProcessor$build_level_lookup()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-build_level_lookup)
- [`Ggplot2LineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_data)
- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_layer_axes)
- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_multiline_data)
- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_single_line_data)
- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_main_polyline_grob)
- [`Ggplot2LineLayerProcessor$format_x_value()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-format_x_value)
- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_multiline_selectors)
- [`Ggplot2LineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_selectors)
- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_single_line_selector)
- [`Ggplot2LineLayerProcessor$get_group_column()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_group_column)
- [`Ggplot2LineLayerProcessor$get_layer()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_layer)
- [`Ggplot2LineLayerProcessor$get_x_transformation()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_x_transformation)
- [`Ggplot2LineLayerProcessor$has_series_groups()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-has_series_groups)
- [`Ggplot2LineLayerProcessor$line_layer_position()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-line_layer_position)
- [`Ggplot2LineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-needs_reordering)
- [`Ggplot2LineLayerProcessor$normalize_point_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-normalize_point_values)
- [`Ggplot2LineLayerProcessor$panel_axis_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-panel_axis_labels)
- [`Ggplot2LineLayerProcessor$polyline_curve_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-polyline_curve_count)
- [`Ggplot2LineLayerProcessor$recover_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-recover_x_values)
- [`Ggplot2LineLayerProcessor$series_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-series_count)
- [`Ggplot2LineLayerProcessor$transform_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-transform_x_values)

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$process()`

Process the polygon layer as a closed path

The reading is the line processor's: one series per `group`, in the
built data's row order, named from whatever aesthetic splits the layer.
Only the type and the selectors are this class's own.

#### Usage

    Ggplot2PolygonLayerProcessor$process(
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

  Panel context for patchwork leaves and facets

#### Returns

List with data, selectors, title, axes and type

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$resolve_group_mapping()`

Resolve the aesthetic that splits this layer into series

A line probes `colour` alone, because a line has no fill. A polygon has
both, and `fill` is the one it is usually split by – so `fill` is probed
first, then the outline colour, then `group` itself.

`group` is the addition, and it is worth its line. A polygon is drawn
one shape per group, and `aes(group = g)` with nothing else mapped is
the plainest way to write two shapes – it is how ggplot2's own
documentation writes them. Without it both series fall back to "Series
1" and "Series 2" while the chart's own data says "a" and "b". ggplot2
records the column under `labels$group` exactly as it records a legend
title, so the z label comes out as "g" and a reader hears "g is a"
rather than "Group is Series 1".

#### Usage

    Ggplot2PolygonLayerProcessor$resolve_group_mapping(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

list with `aes` (aesthetic spelling variants, or NULL when nothing is
mapped) and `column` (the mapped column name, or "group" as a fallback)

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$attach_group_axis()`

Add the grouping column's name as the z axis label

#### Usage

    Ggplot2PolygonLayerProcessor$attach_group_axis(plot, built, data, axes)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `data`:

  The extracted layer data

- `axes`:

  Axes built so far

#### Returns

The axes list, with z added when the layer is grouped

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$group_aes()`

The aesthetics a polygon layer can be split by, in order

#### Usage

    Ggplot2PolygonLayerProcessor$group_aes()

#### Returns

List of aesthetic-name vectors, each holding the spelling variants of
one aesthetic

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$curve_selectors()`

Selectors for this layer's polygons, one per series

Declines when the drawn shape count and the emitted series count
disagree, which is what the line processor does and for the same reason:
the frontend's multiline trace drops the whole layer's highlight unless
`selectors.length === data.length`, so a mismatched list would outline
the wrong shape rather than none.

#### Usage

    Ggplot2PolygonLayerProcessor$curve_selectors(plot, panel_grob, n_series)

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

- `n_series`:

  Number of series the layer emitted

#### Returns

List of CSS selectors, or NULL

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$polygon_shape_count()`

How many shapes one polygon grob draws

`id` separates a `polygon` grob's locations into shapes; a `pathgrob`
uses `id` for its subgroups and `pathId` for the group, so the group is
what has to be counted there – a two-group, two-subgroup layer carries
`id = 1,1,1,1,2,2,2,2,1,...` and `pathId = 1,1,1,1,1,1,1,1,2,...`, and
reading `id` would answer two for a chart drawing two paths of two rings
each only by coincidence.

There is no "it has no ids" case to answer for.
`GeomPolygon$draw_panel()` always passes one – `id = munched$group` for
a polygon, `pathId = munched$group` for a path – so a grob without one
is not one of these, and `length(unique(NULL))` answering zero declines
it, which is the right answer for a grob this should not be addressing.

#### Usage

    Ggplot2PolygonLayerProcessor$polygon_shape_count(grob)

#### Arguments

- `grob`:

  A `polygon` or `pathgrob` grob

#### Returns

The number of shapes drawn

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$find_layer_polygon_grob()`

The polygon grob ggplot2 drew for THIS layer

#### Usage

    Ggplot2PolygonLayerProcessor$find_layer_polygon_grob(
      plot,
      panel_grob,
      target = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

- `target`:

  Index of the layer to find; defaults to this one's

#### Returns

The matching grob, or NULL

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$layer_polygon_grobs()`

Panel polygons that a polygon layer could have drawn

The skip list is not defensive.
[`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)
draws each box's crossbar through `GeomPolygon`, so a boxplot
contributes grobs named exactly like a polygon layer's own – and they
are drawn first. Measured on three boxes beside one polygon:

    geom_boxplot.gTree.30
      geom_boxplot.gTree.10 -> geom_crossbar.gTree.9 -> geom_polygon.polygon.7
      geom_boxplot.gTree.20 -> geom_crossbar.gTree.19 -> geom_polygon.polygon.17
      geom_boxplot.gTree.28 -> geom_crossbar.gTree.27 -> geom_polygon.polygon.25
    geom_polygon.polygon.32                                  <- the layer's own

Taking the first match would outline a box. Every one of those sits
inside a tree named after the geom that owns it, so refusing to descend
into another layer's tree leaves exactly the layer's own – which is how
`layer_polyline_grobs()` scopes the same search for the geoms that draw
anonymous polylines.

#### Usage

    Ggplot2PolygonLayerProcessor$layer_polygon_grobs(
      plot,
      panel_grob,
      target = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `panel_grob`:

  The panel's grob tree

- `target`:

  Index of the layer whose polygons are wanted

#### Returns

List of grobs in draw order

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$polygon_layer_position()`

This layer's position among the plot's polygon layers

Two
[`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
calls draw two grobs in layer order, so the second layer wants the
second match.

#### Usage

    Ggplot2PolygonLayerProcessor$polygon_layer_position(plot, target)

#### Arguments

- `plot`:

  The ggplot2 object

- `target`:

  Index of the layer of interest

#### Returns

The 1-based position, or NULL when the layer is not one

------------------------------------------------------------------------

### `Ggplot2PolygonLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PolygonLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
