# Base R Line Plot Layer Processor

Processes Base R line plot layers based on recorded plot calls

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRLineLayerProcessor`

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

- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](#method-BaseRLineLayerProcessor-generate_selectors_from_grob)

- [`BaseRLineLayerProcessor$clone()`](#method-BaseRLineLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    BaseRLineLayerProcessor$process(
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

    BaseRLineLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    BaseRLineLayerProcessor$extract_data(layer_info)

------------------------------------------------------------------------

### Method `get_axis_labels()`

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

### Method `extract_single_line_data()`

#### Usage

    BaseRLineLayerProcessor$extract_single_line_data(x, y, x_labels = NULL)

------------------------------------------------------------------------

### Method `extract_multiline_data()`

#### Usage

    BaseRLineLayerProcessor$extract_multiline_data(x, y_matrix, x_labels = NULL)

------------------------------------------------------------------------

### Method `extract_axis_titles()`

#### Usage

    BaseRLineLayerProcessor$extract_axis_titles(layer_info)

------------------------------------------------------------------------

### Method `extract_abline_data()`

#### Usage

    BaseRLineLayerProcessor$extract_abline_data(layer_info)

------------------------------------------------------------------------

### Method `get_x_range_from_group()`

#### Usage

    BaseRLineLayerProcessor$get_x_range_from_group(group)

------------------------------------------------------------------------

### Method `get_y_range_from_group()`

#### Usage

    BaseRLineLayerProcessor$get_y_range_from_group(group)

------------------------------------------------------------------------

### Method `extract_main_title()`

#### Usage

    BaseRLineLayerProcessor$extract_main_title(layer_info)

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    BaseRLineLayerProcessor$generate_selectors(layer_info, gt = NULL)

------------------------------------------------------------------------

### Method `find_lines_grobs()`

#### Usage

    BaseRLineLayerProcessor$find_lines_grobs(
      grob,
      group_index,
      grob_type = "lines"
    )

------------------------------------------------------------------------

### Method `generate_selectors_from_grob()`

#### Usage

    BaseRLineLayerProcessor$generate_selectors_from_grob(
      grob,
      group_index,
      layer_info
    )

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRLineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
