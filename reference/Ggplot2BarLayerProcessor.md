# Bar Layer Processor

Processes bar plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `Ggplot2BarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2BarLayerProcessor$process()`](#method-Ggplot2BarLayerProcessor-process)

- [`Ggplot2BarLayerProcessor$needs_reordering()`](#method-Ggplot2BarLayerProcessor-needs_reordering)

- [`Ggplot2BarLayerProcessor$reorder_layer_data()`](#method-Ggplot2BarLayerProcessor-reorder_layer_data)

- [`Ggplot2BarLayerProcessor$extract_data()`](#method-Ggplot2BarLayerProcessor-extract_data)

- [`Ggplot2BarLayerProcessor$generate_selectors()`](#method-Ggplot2BarLayerProcessor-generate_selectors)

- [`Ggplot2BarLayerProcessor$clone()`](#method-Ggplot2BarLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$set_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2BarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    Ggplot2BarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `reorder_layer_data()`

#### Usage

    Ggplot2BarLayerProcessor$reorder_layer_data(data, plot)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2BarLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL,
      panel_id = NULL
    )

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2BarLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2BarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
