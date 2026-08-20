# Histogram Layer Processor

Processes histogram plot layers with complete logic included

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2HistogramLayerProcessor`

## Methods

### Public methods

- [`Ggplot2HistogramLayerProcessor$process()`](#method-Ggplot2HistogramLayerProcessor-process)

- [`Ggplot2HistogramLayerProcessor$determine_orientation()`](#method-Ggplot2HistogramLayerProcessor-determine_orientation)

- [`Ggplot2HistogramLayerProcessor$extract_data()`](#method-Ggplot2HistogramLayerProcessor-extract_data)

- [`Ggplot2HistogramLayerProcessor$generate_selectors()`](#method-Ggplot2HistogramLayerProcessor-generate_selectors)

- [`Ggplot2HistogramLayerProcessor$clone()`](#method-Ggplot2HistogramLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2HistogramLayerProcessor$process()`

#### Usage

    Ggplot2HistogramLayerProcessor$process(
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

### `Ggplot2HistogramLayerProcessor$determine_orientation()`

Which axis this histogram's bins run along

[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
fills a flipped layer's `ymin`/`ymax` with the bin bounds and its `x`
with the count, and `extract_data` above passes both through as they
come – so the emitted data is already transposed correctly. What was
missing is this key saying so.

Without it the frontend defaults to vertical and reads the bin range
from `xMin`/`xMax`, which on a flipped layer hold the count bounds. A
[`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html)
drawn with `aes(y = v)` was announced with a bin range of "0 to 5" –
counts – where the data runs -2.42 to -1.10, and with every bin centre
offered as a value. Every number real, every one on the wrong axis, and
nothing erroring (#163).

Read from `flipped_aes`, which ggplot2 sets on the built layer, the way
the boxplot and violin processors already do.
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
is a different question and deliberately not answered here: it leaves
`flipped_aes` alone and rotates only the coordinate system, so the data
layout this key describes is genuinely unflipped. Treating it as
horizontal would swap a pair that is already the right way round.

#### Usage

    Ggplot2HistogramLayerProcessor$determine_orientation(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object.

- `built`:

  Its
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  result, when the caller already has one.

#### Returns

`"horz"` or `"vert"`.

------------------------------------------------------------------------

### `Ggplot2HistogramLayerProcessor$extract_data()`

#### Usage

    Ggplot2HistogramLayerProcessor$extract_data(
      plot,
      built = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

------------------------------------------------------------------------

### `Ggplot2HistogramLayerProcessor$generate_selectors()`

#### Usage

    Ggplot2HistogramLayerProcessor$generate_selectors(
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

### `Ggplot2HistogramLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2HistogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
