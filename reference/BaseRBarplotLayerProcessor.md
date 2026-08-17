# Base R Bar Plot Layer Processor

Processes Base R bar plot layers based on recorded plot calls

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRBarplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBarplotLayerProcessor$process()`](#method-BaseRBarplotLayerProcessor-process)

- [`BaseRBarplotLayerProcessor$is_horizontal()`](#method-BaseRBarplotLayerProcessor-is_horizontal)

- [`BaseRBarplotLayerProcessor$needs_reordering()`](#method-BaseRBarplotLayerProcessor-needs_reordering)

- [`BaseRBarplotLayerProcessor$extract_data()`](#method-BaseRBarplotLayerProcessor-extract_data)

- [`BaseRBarplotLayerProcessor$extract_axis_titles()`](#method-BaseRBarplotLayerProcessor-extract_axis_titles)

- [`BaseRBarplotLayerProcessor$extract_main_title()`](#method-BaseRBarplotLayerProcessor-extract_main_title)

- [`BaseRBarplotLayerProcessor$generate_selectors()`](#method-BaseRBarplotLayerProcessor-generate_selectors)

- [`BaseRBarplotLayerProcessor$find_rect_grobs()`](#method-BaseRBarplotLayerProcessor-find_rect_grobs)

- [`BaseRBarplotLayerProcessor$generate_selectors_from_grob()`](#method-BaseRBarplotLayerProcessor-generate_selectors_from_grob)

- [`BaseRBarplotLayerProcessor$clone()`](#method-BaseRBarplotLayerProcessor-clone)

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

### `BaseRBarplotLayerProcessor$process()`

#### Usage

    BaseRBarplotLayerProcessor$process(
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

### `BaseRBarplotLayerProcessor$is_horizontal()`

Check whether this barplot call used horiz = TRUE

#### Usage

    BaseRBarplotLayerProcessor$is_horizontal(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Logical

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$needs_reordering()`

#### Usage

    BaseRBarplotLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$extract_data()`

#### Usage

    BaseRBarplotLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRBarplotLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$extract_main_title()`

#### Usage

    BaseRBarplotLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$generate_selectors()`

#### Usage

    BaseRBarplotLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$find_rect_grobs()`

Recursively find rect grobs in the grob tree (like ggplot2 does)

#### Usage

    BaseRBarplotLayerProcessor$find_rect_grobs(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  The plot call index to match

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$generate_selectors_from_grob()`

Generate selectors from grob tree (like ggplot2 does)

#### Usage

    BaseRBarplotLayerProcessor$generate_selectors_from_grob(grob, call_index)

#### Arguments

- `grob`:

  The grob tree to search

- `call_index`:

  The plot call index

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRBarplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBarplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
