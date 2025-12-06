# Base R Heatmap Layer Processor

Processes Base R heatmap layers using the heatmap() function

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `BaseRHeatmapLayerProcessor`

## Methods

### Public methods

- [`BaseRHeatmapLayerProcessor$process()`](#method-BaseRHeatmapLayerProcessor-process)

- [`BaseRHeatmapLayerProcessor$extract_data()`](#method-BaseRHeatmapLayerProcessor-extract_data)

- [`BaseRHeatmapLayerProcessor$generate_selectors()`](#method-BaseRHeatmapLayerProcessor-generate_selectors)

- [`BaseRHeatmapLayerProcessor$find_image_rect_grobs()`](#method-BaseRHeatmapLayerProcessor-find_image_rect_grobs)

- [`BaseRHeatmapLayerProcessor$generate_selectors_from_grob()`](#method-BaseRHeatmapLayerProcessor-generate_selectors_from_grob)

- [`BaseRHeatmapLayerProcessor$extract_axis_titles()`](#method-BaseRHeatmapLayerProcessor-extract_axis_titles)

- [`BaseRHeatmapLayerProcessor$extract_main_title()`](#method-BaseRHeatmapLayerProcessor-extract_main_title)

- [`BaseRHeatmapLayerProcessor$clone()`](#method-BaseRHeatmapLayerProcessor-clone)

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

    BaseRHeatmapLayerProcessor$process(
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

### Method `extract_data()`

#### Usage

    BaseRHeatmapLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRHeatmapLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_image_rect_grobs()`

#### Usage

    BaseRHeatmapLayerProcessor$find_image_rect_grobs(grob, group_index)

------------------------------------------------------------------------

### Method `generate_selectors_from_grob()`

#### Usage

    BaseRHeatmapLayerProcessor$generate_selectors_from_grob(
      grob,
      group_index = NULL
    )

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRHeatmapLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRHeatmapLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRHeatmapLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
