# Base R Boxplot Layer Processor

Processes Base R boxplot layers by extracting statistical summaries and
generating selectors for boxplot components.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRBoxplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBoxplotLayerProcessor$process()`](#method-BaseRBoxplotLayerProcessor-process)

- [`BaseRBoxplotLayerProcessor$extract_data()`](#method-BaseRBoxplotLayerProcessor-extract_data)

- [`BaseRBoxplotLayerProcessor$generate_selectors()`](#method-BaseRBoxplotLayerProcessor-generate_selectors)

- [`BaseRBoxplotLayerProcessor$extract_axis_titles()`](#method-BaseRBoxplotLayerProcessor-extract_axis_titles)

- [`BaseRBoxplotLayerProcessor$extract_formula_labels()`](#method-BaseRBoxplotLayerProcessor-extract_formula_labels)

- [`BaseRBoxplotLayerProcessor$extract_main_title()`](#method-BaseRBoxplotLayerProcessor-extract_main_title)

- [`BaseRBoxplotLayerProcessor$determine_orientation()`](#method-BaseRBoxplotLayerProcessor-determine_orientation)

- [`BaseRBoxplotLayerProcessor$clone()`](#method-BaseRBoxplotLayerProcessor-clone)

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

### `BaseRBoxplotLayerProcessor$process()`

#### Usage

    BaseRBoxplotLayerProcessor$process(
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

### `BaseRBoxplotLayerProcessor$extract_data()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$generate_selectors()`

#### Usage

    BaseRBoxplotLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_formula_labels()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_formula_labels(args)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_main_title()`

#### Usage

    BaseRBoxplotLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$determine_orientation()`

#### Usage

    BaseRBoxplotLayerProcessor$determine_orientation(layer_info)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBoxplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
