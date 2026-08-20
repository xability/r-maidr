# Contour Layer Processor

Processes contour layers (`geom_contour`, `geom_density_2d`).

A contour is the one chart of its family whose value is a **number
rather than a colour**: ggplot2 computes `level` per row, so both halves
of the reading invert exactly and nothing is recovered from a fill. That
is what separates it from the same chart in a renderer that keeps its
magnitude only in a continuous colour, which is why xability/maidr#1084
left Observable Plot's `contour` unread.

The **filled** forms are not this chart.
[`geom_contour_filled()`](https://ggplot2.tidyverse.org/reference/geom_contour.html)
and
[`geom_density_2d_filled()`](https://ggplot2.tidyverse.org/reference/geom_density_2d.html)
draw the bands *between* levels, and say so in the frame: their `level`
is a factor of intervals rather than a number. Announcing one of those
outlines as a level's own curve would be right for half of its points.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2ContourLayerProcessor`

## Methods

### Public methods

- [`Ggplot2ContourLayerProcessor$process()`](#method-Ggplot2ContourLayerProcessor-process)

- [`Ggplot2ContourLayerProcessor$extract_axes()`](#method-Ggplot2ContourLayerProcessor-extract_axes)

- [`Ggplot2ContourLayerProcessor$generate_selectors()`](#method-Ggplot2ContourLayerProcessor-generate_selectors)

- [`Ggplot2ContourLayerProcessor$clone()`](#method-Ggplot2ContourLayerProcessor-clone)

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2ContourLayerProcessor$process()`

Process the contour layer

#### Usage

    Ggplot2ContourLayerProcessor$process(
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

List with data, selectors and axes

------------------------------------------------------------------------

### `Ggplot2ContourLayerProcessor$extract_axes()`

Name the two axes

Only x and y. The level is not an axis here: it travels on every point
of the curve it belongs to, and the frontend's contour trace announces
it from there under its own heading rather than from a third axis label.

#### Usage

    Ggplot2ContourLayerProcessor$extract_axes(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

#### Returns

An axes payload with x and y

------------------------------------------------------------------------

### `Ggplot2ContourLayerProcessor$generate_selectors()`

Address each drawn curve by its own element

`GeomContour` draws every curve in one `polylineGrob`, and gridSVG
exports that as one `<polyline>` per piece with an id of the form
`<grob>.1.<n>` – measured, a two-level field with two peaks gives
`GRID.polyline.1.1.1` through `.4`. So a curve is addressed by its
position among the pieces, which is what
[`contour_curves()`](https://r.maidr.ai/reference/contour_curves.md)
returns.

The grob carries grid's automatic name rather than one derived from the
geom, so it is found the way a line layer's is – by position among the
auto-named polylines of the panel. That is the whole reason
[`polyline_layer_position()`](https://r.maidr.ai/reference/polyline_layer_position.md)
had to learn about this type: a contour drawn beside a
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
sits in the same candidate list, and a count that skipped it would give
both layers the other's curves.

#### Usage

    Ggplot2ContourLayerProcessor$generate_selectors(
      gt = NULL,
      plot = NULL,
      panel_ctx = NULL,
      order = integer(0)
    )

#### Arguments

- `gt`:

  Gtable object

- `plot`:

  The ggplot2 object, used to build a gtable when none is given

- `panel_ctx`:

  Panel context for patchwork leaves and facets

- `order`:

  The piece behind each emitted curve

#### Returns

A list of CSS selectors, one per curve

------------------------------------------------------------------------

### `Ggplot2ContourLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2ContourLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
