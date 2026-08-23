# Base R Spike Plot Layer Processor

Processes Base R spike layers – `plot(x, y, type = "h")` and the
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) equivalent.
`type = "h"` draws a vertical line from the baseline to each value and
joins nothing to anything: the samples stand side by side rather than in
a series.

Read as a `lollipop` layer, which the core builds on `BarTrace`: one
value per position, with no claim about the space between two of them.
The marker head a lollipop conventionally carries is the only difference
from what base R draws here, and it is not something a reader hears.

Announced as a `line` before this existed, which is the reading a spike
chart most needs not to have – a line says the samples are joined and
that the space between them can be interpolated, and that is the one
relationship the chart is drawn to deny (#239).

Data extraction, axis titles and the main title are a line layer's, so
this inherits `BaseRLineLayerProcessor`; what it adds is the layer
`type`, the flat point list a bar-shaped trace wants, and the grob
family the spikes are actually named after.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRSpikeLayerProcessor`

## Methods

### Public methods

- [`BaseRSpikeLayerProcessor$process()`](#method-BaseRSpikeLayerProcessor-process)

- [`BaseRSpikeLayerProcessor$extract_data()`](#method-BaseRSpikeLayerProcessor-extract_data)

- [`BaseRSpikeLayerProcessor$selector_grob_type()`](#method-BaseRSpikeLayerProcessor-selector_grob_type)

- [`BaseRSpikeLayerProcessor$clone()`](#method-BaseRSpikeLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
- [`BaseRLineLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_axis_titles)
- [`BaseRLineLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_main_title)
- [`BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`BaseRLineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors)
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)

------------------------------------------------------------------------

### `BaseRSpikeLayerProcessor$process()`

Process the spike layer.

#### Usage

    BaseRSpikeLayerProcessor$process(
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

  Unused for Base R (kept for interface compatibility)

- `layout`:

  Unused for Base R (kept for interface compatibility)

- `built`:

  Unused for Base R (kept for interface compatibility)

- `gt`:

  Gtable object used for selector generation (optional)

- `grob_id`:

  Unused for Base R

- `panel_id`:

  Unused for Base R

- `panel_ctx`:

  Unused for Base R

- `layer_info`:

  Information about the recorded plot call

#### Returns

List with data, selectors, type, title and axes

------------------------------------------------------------------------

### `BaseRSpikeLayerProcessor$extract_data()`

Read the spikes as one flat list of points.

A line layer's `data` is a list of *series*, because several lines can
share one layer. A lollipop is read as a bar is, and a bar layer's
`data` is one point per position – so the single series the inherited
extraction produces is unwrapped here rather than shipped one level too
deep, where the frontend would read the whole chart as a single point.

Only the first series is taken. `plot(type = "h")` and
`lines(type = "h")` each draw exactly one, and `matplot` – the call that
draws several – has its own dispatch that never reaches here.

#### Usage

    BaseRSpikeLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

List of `x`/`y` points, empty when there is nothing to read

------------------------------------------------------------------------

### `BaseRSpikeLayerProcessor$selector_grob_type()`

Draw a spike layer's selectors from the spike grobs.

gridGraphics names a grob after what drew it, so spikes land under
`graphics-plot-N-spike-M` – never under the `-lines-` name the inherited
search looks for. Measured on `plot(1:6, y, type = "h")`, one polyline
per spike sits under that grob, in data order:

    <polyline id="graphics-plot-1-spike-1.1.1" points="74.4,... "/>
    <polyline id="graphics-plot-1-spike-1.1.2" points="151.2,..."/>
    ...

so the one selector this yields resolves to one element per point, which
is what a bar-shaped trace pairs with its data.

#### Usage

    BaseRSpikeLayerProcessor$selector_grob_type(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

"spike"

------------------------------------------------------------------------

### `BaseRSpikeLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSpikeLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
