# Base R Point/Scatter Plot Layer Processor

Processes Base R scatter plot layers based on recorded plot calls

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRPointLayerProcessor`

## Methods

### Public methods

- [`BaseRPointLayerProcessor$process()`](#method-BaseRPointLayerProcessor-process)

- [`BaseRPointLayerProcessor$needs_reordering()`](#method-BaseRPointLayerProcessor-needs_reordering)

- [`BaseRPointLayerProcessor$extract_data()`](#method-BaseRPointLayerProcessor-extract_data)

- [`BaseRPointLayerProcessor$resolve_coordinates()`](#method-BaseRPointLayerProcessor-resolve_coordinates)

- [`BaseRPointLayerProcessor$formula_variables()`](#method-BaseRPointLayerProcessor-formula_variables)

- [`BaseRPointLayerProcessor$extract_axis_titles()`](#method-BaseRPointLayerProcessor-extract_axis_titles)

- [`BaseRPointLayerProcessor$extract_base_r_axis_grid_info()`](#method-BaseRPointLayerProcessor-extract_base_r_axis_grid_info)

- [`BaseRPointLayerProcessor$extract_main_title()`](#method-BaseRPointLayerProcessor-extract_main_title)

- [`BaseRPointLayerProcessor$generate_selectors()`](#method-BaseRPointLayerProcessor-generate_selectors)

- [`BaseRPointLayerProcessor$clone()`](#method-BaseRPointLayerProcessor-clone)

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

### `BaseRPointLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

#### Usage

    BaseRPointLayerProcessor$process(
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

### `BaseRPointLayerProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing; a Base R layer
is read from the recorded call and never is

#### Usage

    BaseRPointLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_data()`

One point per observation, from the recorded x and y or from the
formula's model frame

#### Usage

    BaseRPointLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of points

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$resolve_coordinates()`

The x and y a recorded call plots, resolved as plot() resolves them.

`plot(y ~ x, data = d)` carries a formula rather than two vectors, and
its coordinates are the two columns of the model frame the recording
kept (#254). Read from
[`resolve_xy_args()`](https://r.maidr.ai/reference/resolve_xy_args.md)
alone, the formula is a language object and the layer came out with no
points at all – an interactive chart with nothing in it.

#### Usage

    BaseRPointLayerProcessor$resolve_coordinates(plot_call)

#### Arguments

- `plot_call`:

  The recorded call

#### Returns

A list with `x` and `y`, either of which may be NULL

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$formula_variables()`

The two numeric variables of a recorded formula call, or NULL.

Only a numeric pair is a scatter: `plot(y ~ f)` on a factor draws a box
plot through `plot.factor()`, and a frame with more than one predictor
draws something else again. Both are left as they were.

#### Usage

    BaseRPointLayerProcessor$formula_variables(plot_call)

#### Arguments

- `plot_call`:

  The recorded call

#### Returns

A list with `x`, `y`, `x_name`, `y_name`, or NULL

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_axis_titles()`

Extract axis information from Base R plot call

Returns per-axis objects with an optional label and optional grid
navigation fields (min, max, tickStep). Grid fields are derived from
xlim/ylim args or data range, and tick intervals via pretty(). Every
field is included only when extraction succeeds, and an axis that ends
up with none of them is left out of the payload entirely.

#### Usage

    BaseRPointLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information with recorded plot call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_base_r_axis_grid_info()`

Extract grid navigation info for a Base R axis

Computes min, max from xlim/ylim or data range, and tickStep from
pretty() tick positions. Returns NULL if extraction fails.

#### Usage

    BaseRPointLayerProcessor$extract_base_r_axis_grid_info(data, lim = NULL)

#### Arguments

- `data`:

  Numeric vector of data values

- `lim`:

  Optional axis limits (xlim or ylim)

#### Returns

List with min, max, tickStep or NULL

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRPointLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$generate_selectors()`

The selector for the points, scoped to this layer's plot group

#### Usage

    BaseRPointLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRPointLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPointLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
