# Histogram Layer Processor

Processes histogram plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `Ggplot2HistogramLayerProcessor`

## Methods

### Public methods

- [`Ggplot2HistogramLayerProcessor$process()`](#method-Ggplot2HistogramLayerProcessor-process)

- [`Ggplot2HistogramLayerProcessor$extract_data()`](#method-Ggplot2HistogramLayerProcessor-extract_data)

- [`Ggplot2HistogramLayerProcessor$generate_selectors()`](#method-Ggplot2HistogramLayerProcessor-generate_selectors)

- [`Ggplot2HistogramLayerProcessor$clone()`](#method-Ggplot2HistogramLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_reordering()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2HistogramLayerProcessor$process(plot, layout, built = NULL, gt = NULL)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2HistogramLayerProcessor$extract_data(plot, built = NULL)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2HistogramLayerProcessor$generate_selectors(plot, gt = NULL)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2HistogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
