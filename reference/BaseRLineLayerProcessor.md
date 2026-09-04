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

- [`BaseRLineLayerProcessor$axis_extent()`](#method-BaseRLineLayerProcessor-axis_extent)

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

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

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

  Unused; present for the processor interface

- `layout`:

  Unused; present for the processor interface

- `built`:

  Unused; present for the processor interface

- `gt`:

  Gtable of the replayed drawing, searched for selectors (optional)

- `grob_id`:

  Unused; present for the processor interface

- `panel_id`:

  Unused; present for the processor interface

- `panel_ctx`:

  Unused; present for the processor interface

- `layer_info`:

  Layer information with the recorded call

#### Returns

List describing the layer for the MAIDR payload

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing; a Base R layer
is read from the recorded call and never is

#### Usage

    BaseRLineLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_data()`

One series per line: a vector, each column of a matrix, a time series,
or the endpoints of
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md)

#### Usage

    BaseRLineLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of series

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

The points of one line, pairing each x with its y

#### Usage

    BaseRLineLayerProcessor$extract_single_line_data(x, y, x_labels = NULL)

#### Arguments

- `x`:

  x positions

- `y`:

  y values

- `x_labels`:

  Category labels to announce in place of the x positions (optional)

#### Returns

List holding one series

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_multiline_data()`

One series per column of `y_matrix`, named after the columns

#### Usage

    BaseRLineLayerProcessor$extract_multiline_data(x, y_matrix, x_labels = NULL)

#### Arguments

- `x`:

  x positions

- `y_matrix`:

  One column of y values per series

- `x_labels`:

  Category labels to announce in place of the x positions (optional)

#### Returns

List of series

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_axis_titles()`

The axis titles, taken from the HIGH-level call for an overlay such as
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md)

#### Usage

    BaseRLineLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_abline_data()`

The endpoints of an
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
across the axis the HIGH-level call set up

#### Usage

    BaseRLineLayerProcessor$extract_abline_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List holding one two-point series, or empty

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$get_x_range_from_group()`

The x extent of the group's HIGH-level call, as the axis was drawn

#### Usage

    BaseRLineLayerProcessor$get_x_range_from_group(group)

#### Arguments

- `group`:

  The recorded plot group holding the HIGH-level call

#### Returns

Numeric vector of two, or NULL

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$get_y_range_from_group()`

The y extent of the group's HIGH-level call, as the axis was drawn

#### Usage

    BaseRLineLayerProcessor$get_y_range_from_group(group)

#### Arguments

- `group`:

  The recorded plot group holding the HIGH-level call

#### Returns

Numeric vector of two, or NULL

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$axis_extent()`

The extent of an axis the way
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html) sets
it: an explicit `xlim`/`ylim`, or the finite data extended by 4 % each
way, which is what
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws its
clipped line across.

#### Usage

    BaseRLineLayerProcessor$axis_extent(limits, data)

#### Arguments

- `limits`:

  An explicit `xlim`/`ylim`, or NULL

- `data`:

  The plotted values on that axis

#### Returns

Numeric vector of two, or NULL when nothing finite was plotted

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$extract_main_title()`

The main title, taken from the HIGH-level call for
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md)

#### Usage

    BaseRLineLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$generate_selectors()`

One selector per polyline, in series order

#### Usage

    BaseRLineLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$find_lines_grobs()`

Find every grob of the given family drawn by the plot group at
`group_index`

#### Usage

    BaseRLineLayerProcessor$find_lines_grobs(
      grob,
      group_index,
      grob_type = "lines"
    )

#### Arguments

- `grob`:

  The grob tree to search

- `group_index`:

  Index of the recorded plot group, which numbers the panel's grobs

- `grob_type`:

  The grob family to match: "lines", "abline", "segments", "spike" or
  "step"

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$selector_grob_type()`

Which family of grob names this layer's selectors are drawn from:
"abline", "lines", "segments", "spike" or "step". Overridden by
subclasses whose geometry lands under a different grob name (see
BaseRStepLayerProcessor).

#### Usage

    BaseRLineLayerProcessor$selector_grob_type(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

"abline" or "lines"

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$generate_selectors_from_grob()`

One selector per matching polyline, sorted by the grob number

#### Usage

    BaseRLineLayerProcessor$generate_selectors_from_grob(
      grob,
      group_index,
      layer_info
    )

#### Arguments

- `grob`:

  The grob tree to search

- `group_index`:

  Index of the recorded plot group, which numbers the panel's grobs

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRLineLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRLineLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
