# lattice Histogram Layer Processor

Reads the bins a
[`histogram()`](https://rdrr.io/pkg/lattice/man/histogram.html) panel
draws as a `hist` layer.

The bins are read off the drawn rectangles, one per bin from left to
right, in the units the panel drew them in: percent of the panel's
observations by default, or counts or densities as `type =` asks. That
is what the chart shows, and it holds even where the breaks are computed
per panel or from a function; lattice widens the data's range before it
breaks it, so recomputing the bins from the data would not give the same
ones. A bin that holds nothing is still drawn, with no height, and is
read as zero. The frontend's description of a `hist` layer takes every
height for a count and sums them as the number of observations, which a
percent or density histogram's heights are not; the payload has no way
to say what the heights measure.

A factor is binned one level to a bin, each bin centred on the level's
position along the axis, where the axis names the level. That chart is a
bar chart of the levels, and is read as one: a `bar` layer, a bar per
level, named by it. As a `hist` layer each bin would be announced by the
range it spans – "0.5 through 1.5" – which on a factor's axis is only
positions, never the name the chart shows under the bar.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`LatticeLayerProcessor`](https://r.maidr.ai/reference/LatticeLayerProcessor.md)
-\> `LatticeHistogramLayerProcessor`

## Methods

### Public methods

- [`LatticeHistogramLayerProcessor$process()`](#method-LatticeHistogramLayerProcessor-process)

- [`LatticeHistogramLayerProcessor$extract_data()`](#method-LatticeHistogramLayerProcessor-extract_data)

- [`LatticeHistogramLayerProcessor$bin_levels()`](#method-LatticeHistogramLayerProcessor-bin_levels)

- [`LatticeHistogramLayerProcessor$clone()`](#method-LatticeHistogramLayerProcessor-clone)

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

### `LatticeHistogramLayerProcessor$process()`

Read the layer

#### Usage

    LatticeHistogramLayerProcessor$process(
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

### `LatticeHistogramLayerProcessor$extract_data()`

Read the drawn bins

#### Usage

    LatticeHistogramLayerProcessor$extract_data(plot, grob)

#### Arguments

- `plot`:

  The trellis object

- `grob`:

  The rect grob

#### Returns

List of bins, each `x` (its middle), `y` (its height) and the extents
`xMin`, `xMax`, `yMin`, `yMax`

------------------------------------------------------------------------

### `LatticeHistogramLayerProcessor$bin_levels()`

The levels a factor's bins count, one level to a bin

Breaks given for a factor can span several levels, and a bin that counts
more than one has no one name; the bins are then read as bins.

#### Usage

    LatticeHistogramLayerProcessor$bin_levels(bins, x_limits)

#### Arguments

- `bins`:

  The drawn bins, from `extract_data()`

- `x_limits`:

  The packet's x limits: the level names on a factor axis

#### Returns

The level each bin counts, or NULL

------------------------------------------------------------------------

### `LatticeHistogramLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeHistogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
