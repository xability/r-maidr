# Base R Pie Chart Layer Processor

Base R Pie Chart Layer Processor

Base R Pie Chart Layer Processor

## Details

Processes Base R \`pie()\` layers based on recorded plot calls. A pie
layer is 1-D and flat: one point per slice, carrying the slice label as
\`x\` and the slice magnitude as \`y\`. Percentages are derived by the
frontend from those magnitudes, so none are emitted here.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `BaseRPieLayerProcessor`

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

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

Process the pie layer

#### Usage

    BaseRPieLayerProcessor$process(
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

#### Arguments

- `plot`:

  Unused for Base R (NULL)

- `layout`:

  Layout information

- `built`:

  Unused for Base R (NULL)

- `gt`:

  Grob tree used for selector generation

- `scale_mapping`:

  Unused for Base R

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

### Method `needs_reordering()`

Pie slices are emitted in drawing order (see extract_data)

#### Usage

    BaseRPieLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### Method `extract_data()`

Extract one point per slice from the recorded call

#### Usage

    BaseRPieLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Flat list of \`list(x = \<label\>, y = \<value\>)\` points

------------------------------------------------------------------------

### Method `resolve_slice_labels()`

Resolve the per-slice labels the way pie() does

\`labels\` defaults to \`names(x)\`, and falls back to the slice
position when the input is unnamed. \`pie(labels = NA)\` draws neither
label nor leader line, but the wedges are still there and still
navigable, so those slices are announced by position rather than as
"NA".

#### Usage

    BaseRPieLayerProcessor$resolve_slice_labels(values, args)

#### Arguments

- `values`:

  The recorded \`x\` argument (names still attached)

- `args`:

  Recorded argument list from the pie() call

#### Returns

Character vector with one label per slice

------------------------------------------------------------------------

### Method `generate_selectors()`

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

  Points from \[extract_data()\], used for the count

#### Returns

List of CSS selector strings, one per slice

------------------------------------------------------------------------

### Method `find_polygon_grobs()`

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

### Method `extract_axis_titles()`

Extract the axis titles for this layer

x names what the slice labels mean, y what their magnitudes measure.

#### Usage

    BaseRPieLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### Method `extract_main_title()`

Extract the main title for this layer

#### Usage

    BaseRPieLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Character scalar

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPieLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
