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
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$process()`

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

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$needs_reordering()`

#### Usage

    Ggplot2StackedBarProcessor$needs_reordering()

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$reorder_layer_data()`

#### Usage

    Ggplot2StackedBarProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$extract_plot_columns()`

#### Usage

    Ggplot2StackedBarProcessor$extract_plot_columns(plot)

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$extract_data()`

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

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$generate_selectors()`

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

------------------------------------------------------------------------

### `Ggplot2StackedBarProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2StackedBarProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
