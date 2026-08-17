# Base R Smooth/Density Layer Processor

Processes Base R smooth curves including:

- Density plots: plot(density()) or lines(density())

- Loess smooth: lines(loess.smooth()) or lines(predict(loess))

- Smooth splines: lines(smooth.spline())

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRSmoothLayerProcessor`

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$process()`

#### Usage

    BaseRSmoothLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
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

### `BaseRSmoothLayerProcessor$extract_data()`

#### Usage

    BaseRSmoothLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$generate_selectors()`

#### Usage

    BaseRSmoothLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$find_polyline_grobs()`

#### Usage

    BaseRSmoothLayerProcessor$find_polyline_grobs(grob, call_index = NULL)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$generate_selectors_from_grob()`

#### Usage

    BaseRSmoothLayerProcessor$generate_selectors_from_grob(grob, call_index = NULL)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRSmoothLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$extract_main_title()`

#### Usage

    BaseRSmoothLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRSmoothLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSmoothLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
