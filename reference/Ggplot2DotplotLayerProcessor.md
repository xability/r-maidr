# Dot Plot Layer Processor

Processes Wilkinson dot plots (`geom_dotplot`).

The layer emits type `hist`, because that is the chart: a stack of dots
is a bar, and the bin and its count are what a reader navigates. The y
axis a dot plot draws is not one – ggplot2's own documentation says the
values on it are meaningless – so the count goes on it here.

Highlighting is not offered, and that is a real limit rather than an
oversight. `GeomDotplot` draws the whole chart as one `dotstackGrob`,
which gridSVG exports as one `<circle>` per *observation*: a bin of
three dots has three elements and no element of its own, while the
frontend's bar traces resolve exactly one element per announced value.
So the bins are announced, sonified and brailled, and nothing lights up
– which is the highlight-only blind spot xability/maidr#814 names, and
strictly better than the static image this chart was before (#201).
[`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html)
draws the same distribution with a rect per bin and highlights.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2DotplotLayerProcessor`

## Methods

### Public methods

- [`Ggplot2DotplotLayerProcessor$process()`](#method-Ggplot2DotplotLayerProcessor-process)

- [`Ggplot2DotplotLayerProcessor$bins_run_up_the_y_axis()`](#method-Ggplot2DotplotLayerProcessor-bins_run_up_the_y_axis)

- [`Ggplot2DotplotLayerProcessor$extract_data()`](#method-Ggplot2DotplotLayerProcessor-extract_data)

- [`Ggplot2DotplotLayerProcessor$extract_axes()`](#method-Ggplot2DotplotLayerProcessor-extract_axes)

- [`Ggplot2DotplotLayerProcessor$clone()`](#method-Ggplot2DotplotLayerProcessor-clone)

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

------------------------------------------------------------------------

### `Ggplot2DotplotLayerProcessor$process()`

Process the dot plot layer

#### Usage

    Ggplot2DotplotLayerProcessor$process(
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

List with type, data, orientation, selectors and axes

------------------------------------------------------------------------

### `Ggplot2DotplotLayerProcessor$bins_run_up_the_y_axis()`

Which axis the values were binned along

Read from the layer's own `binaxis` parameter, which is what decides it:
`geom_dotplot(binaxis = "y")` is the form drawn beside a categorical x,
and its bins run up the y axis. Defaulted to `"x"` to match ggplot2's
own default rather than guessed at from the data.

#### Usage

    Ggplot2DotplotLayerProcessor$bins_run_up_the_y_axis(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

`TRUE` when the bins run up the y axis

------------------------------------------------------------------------

### `Ggplot2DotplotLayerProcessor$extract_data()`

Read the bins out of the built data

Emitted in the shape `Ggplot2HistogramLayerProcessor` emits, so the
frontend's histogram trace reads it unchanged: the bin's centre and
count as `x`/`y`, and the bin's own bounds as `xMin`/`xMax`. A bar rises
from zero, so `yMin` is 0 and `yMax` is the count.

Both are swapped for a layer binned up the y axis, matching what
`orientation = "horz"` tells the frontend to expect.

#### Usage

    Ggplot2DotplotLayerProcessor$extract_data(
      plot,
      built = NULL,
      panel_id = NULL,
      horizontal = FALSE
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `horizontal`:

  Whether the bins run up the y axis

#### Returns

A list of bins, ascending

------------------------------------------------------------------------

### `Ggplot2DotplotLayerProcessor$extract_axes()`

Name the two axes

The bin axis keeps the variable's name through the package's shared
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html)-then-mapping
chain. The other one is named "count" here rather than read from the
plot: ggplot2 labels a dot plot's count axis "count" while drawing
values on it that its own documentation calls meaningless, and reading
that label back would pair a real count with whatever the caller renamed
the fiction to.

#### Usage

    Ggplot2DotplotLayerProcessor$extract_axes(
      plot,
      built = NULL,
      horizontal = FALSE
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `horizontal`:

  Whether the bins run up the y axis

#### Returns

An axes payload with x and y

------------------------------------------------------------------------

### `Ggplot2DotplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2DotplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
