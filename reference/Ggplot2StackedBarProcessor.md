# Stacked Bar Layer Processor

Processes stacked bar plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2StackedBarProcessor`

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

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2StackedBarProcessor$process(plot, layout, built = NULL, gt = NULL)

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    Ggplot2StackedBarProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `reorder_layer_data()`

#### Usage

    Ggplot2StackedBarProcessor$reorder_layer_data(data, plot)

------------------------------------------------------------------------

### Method `extract_plot_columns()`

#### Usage

    Ggplot2StackedBarProcessor$extract_plot_columns(plot)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2StackedBarProcessor$extract_data(plot, built = NULL)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2StackedBarProcessor$generate_selectors(plot, gt = NULL)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2StackedBarProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
