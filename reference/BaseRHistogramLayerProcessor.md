# Base R Histogram Layer Processor

Processes Base R histogram plot layers using verified data extraction
and selector generation logic.

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `BaseRHistogramLayerProcessor`

## Methods

### Public methods

- [`BaseRHistogramLayerProcessor$process()`](#method-BaseRHistogramLayerProcessor-process)

- [`BaseRHistogramLayerProcessor$extract_data()`](#method-BaseRHistogramLayerProcessor-extract_data)

- [`BaseRHistogramLayerProcessor$generate_selectors()`](#method-BaseRHistogramLayerProcessor-generate_selectors)

- [`BaseRHistogramLayerProcessor$find_rect_grobs()`](#method-BaseRHistogramLayerProcessor-find_rect_grobs)

- [`BaseRHistogramLayerProcessor$generate_selectors_from_grob()`](#method-BaseRHistogramLayerProcessor-generate_selectors_from_grob)

- [`BaseRHistogramLayerProcessor$extract_axis_titles()`](#method-BaseRHistogramLayerProcessor-extract_axis_titles)

- [`BaseRHistogramLayerProcessor$extract_main_title()`](#method-BaseRHistogramLayerProcessor-extract_main_title)

- [`BaseRHistogramLayerProcessor$clone()`](#method-BaseRHistogramLayerProcessor-clone)

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

    BaseRHistogramLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      layer_info = NULL
    )

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRHistogramLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRHistogramLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_rect_grobs()`

#### Usage

    BaseRHistogramLayerProcessor$find_rect_grobs(grob, call_index)

------------------------------------------------------------------------

### Method `generate_selectors_from_grob()`

#### Usage

    BaseRHistogramLayerProcessor$generate_selectors_from_grob(
      grob,
      call_index = NULL
    )

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRHistogramLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRHistogramLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRHistogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
