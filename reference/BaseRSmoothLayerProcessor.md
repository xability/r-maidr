# Base R Smooth/Density Layer Processor

Processes Base R smooth curves including: - Density plots:
plot(density()) or lines(density()) - Loess smooth:
lines(loess.smooth()) or lines(predict(loess)) - Smooth splines:
lines(smooth.spline())

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRSmoothLayerProcessor`

## Methods

### Public methods

- [`BaseRSmoothLayerProcessor$process()`](#method-BaseRSmoothLayerProcessor-process)

- [`BaseRSmoothLayerProcessor$extract_data()`](#method-BaseRSmoothLayerProcessor-extract_data)

- [`BaseRSmoothLayerProcessor$generate_selectors()`](#method-BaseRSmoothLayerProcessor-generate_selectors)

- [`BaseRSmoothLayerProcessor$find_polyline_grobs()`](#method-BaseRSmoothLayerProcessor-find_polyline_grobs)

- [`BaseRSmoothLayerProcessor$generate_selectors_from_grob()`](#method-BaseRSmoothLayerProcessor-generate_selectors_from_grob)

- [`BaseRSmoothLayerProcessor$extract_axis_titles()`](#method-BaseRSmoothLayerProcessor-extract_axis_titles)

- [`BaseRSmoothLayerProcessor$extract_main_title()`](#method-BaseRSmoothLayerProcessor-extract_main_title)

- [`BaseRSmoothLayerProcessor$clone()`](#method-BaseRSmoothLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    BaseRSmoothLayerProcessor$process(
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

    BaseRSmoothLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRSmoothLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_polyline_grobs()`

#### Usage

    BaseRSmoothLayerProcessor$find_polyline_grobs(grob, call_index = NULL)

------------------------------------------------------------------------

### Method `generate_selectors_from_grob()`

#### Usage

    BaseRSmoothLayerProcessor$generate_selectors_from_grob(grob, call_index = NULL)

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRSmoothLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRSmoothLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSmoothLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
