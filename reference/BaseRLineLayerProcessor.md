# Base R Line Plot Layer Processor

Processes Base R line plot layers based on recorded plot calls

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRLineLayerProcessor`

## Methods

### Public methods

- [`BaseRLineLayerProcessor$process()`](#method-BaseRLineLayerProcessor-process)

- [`BaseRLineLayerProcessor$needs_reordering()`](#method-BaseRLineLayerProcessor-needs_reordering)

- [`BaseRLineLayerProcessor$extract_data()`](#method-BaseRLineLayerProcessor-extract_data)

- [`BaseRLineLayerProcessor$get_axis_labels()`](#method-BaseRLineLayerProcessor-get_axis_labels)

- [`BaseRLineLayerProcessor$extract_single_line_data()`](#method-BaseRLineLayerProcessor-extract_single_line_data)

- [`BaseRLineLayerProcessor$extract_multiline_data()`](#method-BaseRLineLayerProcessor-extract_multiline_data)

- [`BaseRLineLayerProcessor$extract_axis_titles()`](#method-BaseRLineLayerProcessor-extract_axis_titles)

- [`BaseRLineLayerProcessor$extract_abline_data()`](#method-BaseRLineLayerProcessor-extract_abline_data)

- [`BaseRLineLayerProcessor$get_x_range_from_group()`](#method-BaseRLineLayerProcessor-get_x_range_from_group)

- [`BaseRLineLayerProcessor$get_y_range_from_group()`](#method-BaseRLineLayerProcessor-get_y_range_from_group)

- [`BaseRLineLayerProcessor$extract_main_title()`](#method-BaseRLineLayerProcessor-extract_main_title)

- [`BaseRLineLayerProcessor$generate_selectors()`](#method-BaseRLineLayerProcessor-generate_selectors)

- [`BaseRLineLayerProcessor$find_lines_grobs()`](#method-BaseRLineLayerProcessor-find_lines_grobs)

- [`BaseRLineLayerProcessor$selector_grob_type()`](#method-BaseRLineLayerProcessor-selector_grob_type)

- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](#method-BaseRLineLayerProcessor-generate_selectors_from_grob)

- [`BaseRLineLayerProcessor$clone()`](#method-BaseRLineLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_polyline_grob)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$layer_polyline_grobs()`](https://r.maidr.ai/reference/LayerProcessor.html#method-layer_polyline_grobs)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$process()`

#### Usage

    BaseRLineLayerProcessor$process(
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

### `BaseRLineLayerProcessor$needs_reordering()`

#### Usage

    BaseRLineLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_data()`

#### Usage

    BaseRLineLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$get_axis_labels()`

Get custom axis labels from axis() LOW-level calls

#### Usage

    BaseRLineLayerProcessor$get_axis_labels(layer_info, axis_side = 1)

#### Arguments

- `layer_info`:

  Layer information containing group data

- `axis_side`:

  Which axis (1=bottom/x, 2=left/y, 3=top, 4=right)

#### Returns

Character vector of labels or NULL if not found

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_single_line_data()`

#### Usage

    BaseRLineLayerProcessor$extract_single_line_data(x, y, x_labels = NULL)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_multiline_data()`

#### Usage

    BaseRLineLayerProcessor$extract_multiline_data(x, y_matrix, x_labels = NULL)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_axis_titles()`

#### Usage

    BaseRLineLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_abline_data()`

#### Usage

    BaseRLineLayerProcessor$extract_abline_data(layer_info)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$get_x_range_from_group()`

#### Usage

    BaseRLineLayerProcessor$get_x_range_from_group(group)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$get_y_range_from_group()`

#### Usage

    BaseRLineLayerProcessor$get_y_range_from_group(group)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_main_title()`

#### Usage

    BaseRLineLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$generate_selectors()`

#### Usage

    BaseRLineLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `gt`:

  Gtable object (optional)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$find_lines_grobs()`

#### Usage

    BaseRLineLayerProcessor$find_lines_grobs(
      grob,
      group_index,
      grob_type = "lines"
    )

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$selector_grob_type()`

#### Usage

    BaseRLineLayerProcessor$selector_grob_type(layer_info)

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$generate_selectors_from_grob()`

#### Usage

    BaseRLineLayerProcessor$generate_selectors_from_grob(
      grob,
      group_index,
      layer_info
    )

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRLineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
