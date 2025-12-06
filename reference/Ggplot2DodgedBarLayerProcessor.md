# Dodged Bar Layer Processor

Processes dodged bar plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `Ggplot2DodgedBarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2DodgedBarLayerProcessor$process()`](#method-Ggplot2DodgedBarLayerProcessor-process)

- [`Ggplot2DodgedBarLayerProcessor$needs_reordering()`](#method-Ggplot2DodgedBarLayerProcessor-needs_reordering)

- [`Ggplot2DodgedBarLayerProcessor$reorder_layer_data()`](#method-Ggplot2DodgedBarLayerProcessor-reorder_layer_data)

- [`Ggplot2DodgedBarLayerProcessor$extract_data()`](#method-Ggplot2DodgedBarLayerProcessor-extract_data)

- [`Ggplot2DodgedBarLayerProcessor$generate_selectors()`](#method-Ggplot2DodgedBarLayerProcessor-generate_selectors)

- [`Ggplot2DodgedBarLayerProcessor$clone()`](#method-Ggplot2DodgedBarLayerProcessor-clone)

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

    Ggplot2DodgedBarLayerProcessor$process(plot, layout, built = NULL, gt = NULL)

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `reorder_layer_data()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$reorder_layer_data(data, plot)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$extract_data(plot, built = NULL)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$generate_selectors(plot, gt = NULL)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2DodgedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
