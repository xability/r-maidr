# Stacked Bar Layer Processor

Processes stacked bar plot layers with complete logic included

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2StackedBarProcessor`

## Methods

### Public methods

- [`Ggplot2StackedBarProcessor$process()`](#method-Ggplot2StackedBarProcessor-process)

- [`Ggplot2StackedBarProcessor$needs_reordering()`](#method-Ggplot2StackedBarProcessor-needs_reordering)

- [`Ggplot2StackedBarProcessor$reorder_layer_data()`](#method-Ggplot2StackedBarProcessor-reorder_layer_data)

- [`Ggplot2StackedBarProcessor$extract_plot_columns()`](#method-Ggplot2StackedBarProcessor-extract_plot_columns)

- [`Ggplot2StackedBarProcessor$extract_data()`](#method-Ggplot2StackedBarProcessor-extract_data)

- [`Ggplot2StackedBarProcessor$generate_selectors()`](#method-Ggplot2StackedBarProcessor-generate_selectors)

- [`Ggplot2StackedBarProcessor$clone()`](#method-Ggplot2StackedBarProcessor-clone)

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
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$process()`

Process the layer: read its series, selectors and the fill legend title
from the built plot

#### Usage

    Ggplot2StackedBarProcessor$process(
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

List describing the layer for the MAIDR payload

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing, so the emitted
order matches the drawn rects

#### Usage

    Ggplot2StackedBarProcessor$needs_reordering()

#### Returns

TRUE

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$reorder_layer_data()`

Reorder the plot data by category and fill so the emitted rows match the
drawn rects

#### Usage

    Ggplot2StackedBarProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  The data frame ggplot2 will draw from

- `plot`:

  The ggplot2 object

#### Returns

The reordered data frame

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$extract_plot_columns()`

The column names the plot maps to x, y and fill

#### Usage

    Ggplot2StackedBarProcessor$extract_plot_columns(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

List with `category_col`, `value_col` and `fill_col`

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$extract_data()`

One series per fill level, restricted to the panel's rows under faceting

#### Usage

    Ggplot2StackedBarProcessor$extract_data(
      plot,
      built = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

#### Returns

List of series

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$generate_selectors()`

One flat selector matching every rect in the layer, which is the
contract the frontend expects (see the note above)

#### Usage

    Ggplot2StackedBarProcessor$generate_selectors(
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

#### Returns

List holding one selector

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2StackedBarProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
