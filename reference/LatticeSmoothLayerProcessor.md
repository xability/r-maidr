# lattice Smooth Layer Processor

Reads the curves lattice computes while it draws as a `smooth` layer,
one series per group: the density estimate of a
[`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html), and
the loess, spline and least-squares fits of `xyplot(type = "smooth")`,
`"spline"` and `"r"`.

The curve is read off the drawn grob rather than computed again: it is
the curve the panel function drew, whatever bandwidth, span or limits it
was given. A least-squares fit is drawn as one segment, clipped to the
panel, and is read as its two ends.

The observations
[`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html) draws
under its curve – jittered points or a rug – are the data again rather
than the reading, and are left out, as the curve is what the chart is
drawn to show.

A fit over a factor axis – `type = "r"`, `"smooth"` or `"spline"` on a
[`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), a
[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) or an
[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a factor –
is not read, and the chart is shown as an image. lattice fits it to the
levels' positions, `1..n`, and draws it between them and out to the
panel's edges, where no level is: read as drawn it would announce "cyl
is 1" where the axis says 4, and "cyl is 0.4" where it says nothing.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticeSmoothLayerProcessor`

## Methods

### Public methods

- [`LatticeSmoothLayerProcessor$process()`](#method-LatticeSmoothLayerProcessor-process)

- [`LatticeSmoothLayerProcessor$extract_series()`](#method-LatticeSmoothLayerProcessor-extract_series)

- [`LatticeSmoothLayerProcessor$clone()`](#method-LatticeSmoothLayerProcessor-clone)

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

### `LatticeSmoothLayerProcessor$process()`

Read the layer

#### Usage

    LatticeSmoothLayerProcessor$process(
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

### `LatticeSmoothLayerProcessor$extract_series()`

Read one drawn curve as a series of points

#### Usage

    LatticeSmoothLayerProcessor$extract_series(plot, grob, panel_ctx = NULL)

#### Arguments

- `plot`:

  The trellis object

- `grob`:

  The lines or segments grob

- `panel_ctx`:

  The panel, which says whether an axis is a time; a time axis is read
  as drawn without it

#### Returns

List of points, or NULL for a grob that is not a curve

------------------------------------------------------------------------

### `LatticeSmoothLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeSmoothLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
