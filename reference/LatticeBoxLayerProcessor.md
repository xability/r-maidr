# lattice Box Layer Processor

Reads a [`bwplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) panel
as a `box` layer: one box per level the panel holds, each with its five
statistics and its outliers.

The statistics are computed the way
[`panel.bwplot()`](https://rdrr.io/pkg/lattice/man/panel.bwplot.html)
computes them – its `stats` function,
[`boxplot.stats()`](https://rdrr.io/r/grDevices/boxplot.stats.html)
unless the chart gave another, with the chart's `coef` and `do.out` –
over the levels the panel holds, so a level with no rows in a packet has
no box there. A box's whiskers end at `min` and `max`, and its outliers
are the values outside them, in the order they were drawn; an outlier
lattice cannot place, such as a zero on a log scale, draws no mark and
is not read.

On a log scale lattice hands the panel the logarithms and computes the
statistics over them, so the box is drawn at those; each statistic is
then read back on the data's own scale, the one the axis is labelled in,
as the other lattice readings are
([`lattice_untransform()`](https://r.maidr.ai/reference/lattice_untransform.md)).
On a date or date-time axis it is the instant it stands for, which the
axis' time format announces as a date
([`lattice_time_milliseconds()`](https://r.maidr.ai/reference/lattice_time_milliseconds.md)).

**Selectors.**
[`panel.bwplot()`](https://rdrr.io/pkg/lattice/man/panel.bwplot.html)
draws each part of every box in one grob: the boxes as polygons, the
whisker caps as segments (the lower caps first, then the upper), the
medians as points – or segments, with `pch = "|"` – and the outliers box
by box. Each part of each box is named by its own id.

A horizontal panel – `factor ~ numeric`, the default – runs its levels
up the vertical axis; the layer is emitted top first, which the frontend
turns round so a reader starts at the bottom, as every other horizontal
box chart in this package does
([`reverse_horizontal_box_layer()`](https://r.maidr.ai/reference/reverse_horizontal_box_layer.md)).

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticeBoxLayerProcessor`

## Methods

### Public methods

- [`LatticeBoxLayerProcessor$process()`](#method-LatticeBoxLayerProcessor-process)

- [`LatticeBoxLayerProcessor$clone()`](#method-LatticeBoxLayerProcessor-clone)

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

### `LatticeBoxLayerProcessor$process()`

Read the layer

#### Usage

    LatticeBoxLayerProcessor$process(
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

### `LatticeBoxLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeBoxLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
