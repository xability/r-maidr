# Base R Histogram Layer Processor

Processes Base R histogram plot layers using verified data extraction
and selector generation logic.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRHistogramLayerProcessor`

## Methods

### Public methods

- [`BaseRHistogramLayerProcessor$process()`](#method-BaseRHistogramLayerProcessor-process)

- [`BaseRHistogramLayerProcessor$extract_data()`](#method-BaseRHistogramLayerProcessor-extract_data)

- [`BaseRHistogramLayerProcessor$recompute_histogram()`](#method-BaseRHistogramLayerProcessor-recompute_histogram)

- [`BaseRHistogramLayerProcessor$is_frequency()`](#method-BaseRHistogramLayerProcessor-is_frequency)

- [`BaseRHistogramLayerProcessor$generate_selectors()`](#method-BaseRHistogramLayerProcessor-generate_selectors)

- [`BaseRHistogramLayerProcessor$find_rect_grobs()`](#method-BaseRHistogramLayerProcessor-find_rect_grobs)

- [`BaseRHistogramLayerProcessor$generate_selectors_from_grob()`](#method-BaseRHistogramLayerProcessor-generate_selectors_from_grob)

- [`BaseRHistogramLayerProcessor$extract_axis_titles()`](#method-BaseRHistogramLayerProcessor-extract_axis_titles)

- [`BaseRHistogramLayerProcessor$frequency_label()`](#method-BaseRHistogramLayerProcessor-frequency_label)

- [`BaseRHistogramLayerProcessor$extract_main_title()`](#method-BaseRHistogramLayerProcessor-extract_main_title)

- [`BaseRHistogramLayerProcessor$clone()`](#method-BaseRHistogramLayerProcessor-clone)

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

### `BaseRHistogramLayerProcessor$process()`

#### Usage

    BaseRHistogramLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
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

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$extract_data()`

#### Usage

    BaseRHistogramLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$recompute_histogram()`

#### Usage

    BaseRHistogramLayerProcessor$recompute_histogram(args)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$is_frequency()`

#### Usage

    BaseRHistogramLayerProcessor$is_frequency(args, hist_obj = NULL)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$generate_selectors()`

#### Usage

    BaseRHistogramLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$find_rect_grobs()`

#### Usage

    BaseRHistogramLayerProcessor$find_rect_grobs(grob, call_index)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$generate_selectors_from_grob()`

#### Usage

    BaseRHistogramLayerProcessor$generate_selectors_from_grob(
      grob,
      call_index = NULL
    )

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRHistogramLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$frequency_label()`

#### Usage

    BaseRHistogramLayerProcessor$frequency_label(args)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$extract_main_title()`

#### Usage

    BaseRHistogramLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRHistogramLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRHistogramLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
