# Heatmap Layer Processor

Processes heatmap layers (geom_tile) with generic data and grob
reordering

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2HeatmapLayerProcessor`

## Methods

### Public methods

- [`Ggplot2HeatmapLayerProcessor$process()`](#method-Ggplot2HeatmapLayerProcessor-process)

- [`Ggplot2HeatmapLayerProcessor$needs_reordering()`](#method-Ggplot2HeatmapLayerProcessor-needs_reordering)

- [`Ggplot2HeatmapLayerProcessor$reorder_layer_data()`](#method-Ggplot2HeatmapLayerProcessor-reorder_layer_data)

- [`Ggplot2HeatmapLayerProcessor$is_binned_layer()`](#method-Ggplot2HeatmapLayerProcessor-is_binned_layer)

- [`Ggplot2HeatmapLayerProcessor$extract_binned_data()`](#method-Ggplot2HeatmapLayerProcessor-extract_binned_data)

- [`Ggplot2HeatmapLayerProcessor$format_bin_edge()`](#method-Ggplot2HeatmapLayerProcessor-format_bin_edge)

- [`Ggplot2HeatmapLayerProcessor$bin_labels()`](#method-Ggplot2HeatmapLayerProcessor-bin_labels)

- [`Ggplot2HeatmapLayerProcessor$extract_data()`](#method-Ggplot2HeatmapLayerProcessor-extract_data)

- [`Ggplot2HeatmapLayerProcessor$generate_selectors()`](#method-Ggplot2HeatmapLayerProcessor-generate_selectors)

- [`Ggplot2HeatmapLayerProcessor$clone()`](#method-Ggplot2HeatmapLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$process()`

#### Usage

    Ggplot2HeatmapLayerProcessor$process(
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

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$needs_reordering()`

#### Usage

    Ggplot2HeatmapLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$reorder_layer_data()`

#### Usage

    Ggplot2HeatmapLayerProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$is_binned_layer()`

Report whether this layer's grid was computed by a stat.

[`geom_bin_2d()`](https://ggplot2.tidyverse.org/reference/geom_bin_2d.html)
is `GeomTile` + `StatBin2d`, so it arrives here classified as a heatmap
– correctly, since a rectangular bin grid is one. What differs is where
the grid comes from: a
[`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
heatmap is handed one in `plot$data`, and a binned one has its computed
for it.

Matched on the stat rather than on the presence of a `count` column,
because a tidy heatmap whose value column happens to be named `count` is
not a binned layer and must not take that path. Reached through
`get_own_layer()`, which already answers "is there a layer at my index?"
– a second bounds check here would be a second place for the answer to
change.

#### Usage

    Ggplot2HeatmapLayerProcessor$is_binned_layer(plot)

#### Arguments

- `plot`:

  The ggplot object

#### Returns

`TRUE` when the layer's stat computes a 2D bin grid

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$extract_binned_data()`

Read a computed 2D bin grid out of the built data.

The built data *is* the grid: one row per drawn tile, carrying the bin's
count and its edges. Only the bins that hold something are present, so
the full rectangle is rebuilt from the distinct positions and the empty
cells left missing rather than scored zero – an empty bin genuinely
counted nothing, but the frontend reads a zero as "no rect here" for
highlighting, and every cell of a heatmap has one.

Axis labels are the bin's coordinate *range*, not its index: "a count of
4" means nothing without "between -2.2 and -1.1", and the range is what
a sighted reader gets from the axis (#136).

#### Usage

    Ggplot2HeatmapLayerProcessor$extract_binned_data(built_data)

#### Arguments

- `built_data`:

  This layer's computed data, already panel-filtered

#### Returns

The same shape `extract_data` returns for a tidy heatmap

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$format_bin_edge()`

Render one bin edge as a short, readable number.

Bin edges are floating point and print at full precision by default –
"-1.1076174999999999 to 1.1076180000000001e-07" is an announcement
nobody can hold in their head. Rounded to a few significant figures, and
trimmed, so the label reads as a coordinate rather than as a machine
number.

#### Usage

    Ggplot2HeatmapLayerProcessor$format_bin_edge(value)

#### Arguments

- `value`:

  A single numeric bin edge or centre

#### Returns

A length-1 character string

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$bin_labels()`

Label each bin by the range it covers.

`xmin`/`xmax` are computed alongside the count, so the range costs
nothing to report and is the only thing that makes the count meaningful.
Falls back to the bin centre when the edges are absent, which is still a
coordinate rather than an index.

#### Usage

    Ggplot2HeatmapLayerProcessor$bin_labels(built_data, positions, axis)

#### Arguments

- `built_data`:

  This layer's computed data

- `positions`:

  The distinct bin centres, sorted

- `axis`:

  `"x"` or `"y"`

#### Returns

Character labels, one per position, in the same order

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$extract_data()`

#### Usage

    Ggplot2HeatmapLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$generate_selectors()`

#### Usage

    Ggplot2HeatmapLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `Ggplot2HeatmapLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2HeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
