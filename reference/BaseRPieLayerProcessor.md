# Base R Pie Chart Layer Processor

Processes Base R
[`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) layers based
on recorded plot calls. A pie layer is 1-D and flat: one point per
slice, carrying the slice label as `x` and the slice magnitude as `y`.
Percentages are derived by the frontend from those magnitudes, so none
are emitted here.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRPieLayerProcessor`

## Methods

### Public methods

- [`BaseRPieLayerProcessor$process()`](#method-BaseRPieLayerProcessor-process)

- [`BaseRPieLayerProcessor$needs_reordering()`](#method-BaseRPieLayerProcessor-needs_reordering)

- [`BaseRPieLayerProcessor$extract_data()`](#method-BaseRPieLayerProcessor-extract_data)

- [`BaseRPieLayerProcessor$resolve_slice_labels()`](#method-BaseRPieLayerProcessor-resolve_slice_labels)

- [`BaseRPieLayerProcessor$generate_selectors()`](#method-BaseRPieLayerProcessor-generate_selectors)

- [`BaseRPieLayerProcessor$find_polygon_grobs()`](#method-BaseRPieLayerProcessor-find_polygon_grobs)

- [`BaseRPieLayerProcessor$extract_axis_titles()`](#method-BaseRPieLayerProcessor-extract_axis_titles)

- [`BaseRPieLayerProcessor$extract_main_title()`](#method-BaseRPieLayerProcessor-extract_main_title)

- [`BaseRPieLayerProcessor$clone()`](#method-BaseRPieLayerProcessor-clone)

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

### `BaseRPieLayerProcessor$process()`

Process the pie layer

#### Usage

    BaseRPieLayerProcessor$process(
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

  Unused for Base R (NULL)

- `layout`:

  Layout information

- `built`:

  Unused for Base R (NULL)

- `gt`:

  Grob tree used for selector generation

- `grob_id`:

  Unused for Base R

- `panel_id`:

  Unused for Base R

- `panel_ctx`:

  Unused for Base R

- `layer_info`:

  Layer information (contains the recorded plot call)

#### Returns

List with data, selectors, type, title and axes

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$needs_reordering()`

Pie slices are emitted in drawing order (see extract_data)

#### Usage

    BaseRPieLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$extract_data()`

Extract one point per slice from the recorded call

#### Usage

    BaseRPieLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Flat list of `list(x = <label>, y = <value>)` points

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$resolve_slice_labels()`

Resolve the per-slice labels the way pie() does

`labels` defaults to `names(x)`, and falls back to the slice position
when the input is unnamed. `pie(labels = NA)` draws neither label nor
leader line, but the wedges are still there and still navigable, so
those slices are announced by position rather than as "NA".

#### Usage

    BaseRPieLayerProcessor$resolve_slice_labels(values, args)

#### Arguments

- `values`:

  The recorded `x` argument (names still attached)

- `args`:

  Recorded argument list from the pie() call

#### Returns

Character vector with one label per slice

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$generate_selectors()`

Generate one selector per wedge, index-aligned to the data

#### Usage

    BaseRPieLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `layer_info`:

  Layer information

- `gt`:

  Grob tree to search

- `extracted_data`:

  Points from `extract_data()`, used for the count

#### Returns

List of CSS selector strings, one per slice

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$find_polygon_grobs()`

Recursively collect this plot's wedge polygon grob names

#### Usage

    BaseRPieLayerProcessor$find_polygon_grobs(grob, plot_index)

#### Arguments

- `grob`:

  The grob tree to search

- `plot_index`:

  The plot (panel) index to match

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

x names what the slice labels mean, y what their magnitudes measure.
[`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) records
neither unless the author wrote one, and a pie always holds labelled
categories against their magnitudes, so the defaults say that much
rather than leaving the axes nameless.

#### Usage

    BaseRPieLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$extract_main_title()`

Extract the main title for this layer

#### Usage

    BaseRPieLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Character scalar

------------------------------------------------------------------------

### `BaseRPieLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPieLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
