# Base R Stacked Bar Layer Processor

Processes Base R stacked bar plot layers intercepted via the patching
system. Assumes sorting by x (columns) and then z (rows) has already
been applied by the `SortingPatcher`.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRStackedBarLayerProcessor`

## Methods

### Public methods

- [`BaseRStackedBarLayerProcessor$process()`](#method-BaseRStackedBarLayerProcessor-process)

- [`BaseRStackedBarLayerProcessor$needs_reordering()`](#method-BaseRStackedBarLayerProcessor-needs_reordering)

- [`BaseRStackedBarLayerProcessor$extract_data()`](#method-BaseRStackedBarLayerProcessor-extract_data)

- [`BaseRStackedBarLayerProcessor$extract_axis_titles()`](#method-BaseRStackedBarLayerProcessor-extract_axis_titles)

- [`BaseRStackedBarLayerProcessor$extract_main_title()`](#method-BaseRStackedBarLayerProcessor-extract_main_title)

- [`BaseRStackedBarLayerProcessor$generate_selectors()`](#method-BaseRStackedBarLayerProcessor-generate_selectors)

- [`BaseRStackedBarLayerProcessor$find_rect_groups()`](#method-BaseRStackedBarLayerProcessor-find_rect_groups)

- [`BaseRStackedBarLayerProcessor$clone()`](#method-BaseRStackedBarLayerProcessor-clone)

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
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$process()`

#### Usage

    BaseRStackedBarLayerProcessor$process(
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

### `BaseRStackedBarLayerProcessor$needs_reordering()`

#### Usage

    BaseRStackedBarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$extract_data()`

#### Usage

    BaseRStackedBarLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRStackedBarLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$extract_main_title()`

#### Usage

    BaseRStackedBarLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$generate_selectors()`

#### Usage

    BaseRStackedBarLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$find_rect_groups()`

#### Usage

    BaseRStackedBarLayerProcessor$find_rect_groups(grob, call_index)

------------------------------------------------------------------------

### `BaseRStackedBarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStackedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
