# Base R Unknown Layer Processor

Processes unknown Base R layer types as a fallback

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `BaseRUnknownLayerProcessor`

## Methods

### Public methods

- [`BaseRUnknownLayerProcessor$process()`](#method-BaseRUnknownLayerProcessor-process)

- [`BaseRUnknownLayerProcessor$needs_reordering()`](#method-BaseRUnknownLayerProcessor-needs_reordering)

- [`BaseRUnknownLayerProcessor$extract_data()`](#method-BaseRUnknownLayerProcessor-extract_data)

- [`BaseRUnknownLayerProcessor$generate_selectors()`](#method-BaseRUnknownLayerProcessor-generate_selectors)

- [`BaseRUnknownLayerProcessor$clone()`](#method-BaseRUnknownLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$reorder_layer_data()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    BaseRUnknownLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
    )

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    BaseRUnknownLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRUnknownLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRUnknownLayerProcessor$generate_selectors(layer_info)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRUnknownLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
