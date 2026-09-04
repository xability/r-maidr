# Base R Boxplot Layer Processor

Processes Base R boxplot layers by extracting statistical summaries and
generating selectors for boxplot components.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRBoxplotLayerProcessor`

## Methods

### Public methods

- [`BaseRBoxplotLayerProcessor$process()`](#method-BaseRBoxplotLayerProcessor-process)

- [`BaseRBoxplotLayerProcessor$read_stats()`](#method-BaseRBoxplotLayerProcessor-read_stats)

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$process()`

Process the layer: read its data, selectors, axis titles and main title
from the recorded call

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

  Unused; present for the processor interface

- `layout`:

  Unused; present for the processor interface

- `built`:

  Unused; present for the processor interface

- `gt`:

  Gtable of the replayed drawing, searched for selectors (optional)

- `layer_info`:

  Layer information with the recorded call

#### Returns

List describing the layer for the MAIDR payload

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$read_stats()`

The five-number summaries the drawn boxes came from

A [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
carries the *observations*, so the summaries have to be recomputed from
them – which `boxplot(plot = FALSE)` does, using the same code path the
drawing did, rather than a reimplementation of it here.
[`graphics::boxplot`](https://rdrr.io/r/graphics/boxplot.html) is named
directly so the replay does not go back through maidr's own wrapper and
record a second call.

Overridable because
[`bxp()`](https://r.maidr.ai/reference/base-r-wrappers.md) is handed the
summaries already computed and draws exactly the same marks from them:
everything below this method – the outlier grouping, the polygon and
segment indices, the shift each box with no outliers puts on the ones
after it – is the same reading either way, and only where the summaries
come from differs (#262).

#### Usage

    BaseRBoxplotLayerProcessor$read_stats(args)

#### Arguments

- `args`:

  Recorded argument list

#### Returns

The `boxplot.stats`-shaped list, or NULL when it cannot be had

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_data()`

One five-number summary per group, recomputed from the recorded
observations

#### Usage

    BaseRBoxplotLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of box summaries

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$generate_selectors()`

Selectors for each box's polygon, whiskers, median and outliers

#### Usage

    BaseRBoxplotLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

- `extracted_data`:

  The data already extracted for this layer (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_axis_titles()`

Extract the axis titles for this layer

[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) records
no title unless the author wrote one, but the formula method derives
both from the formula itself and draws them, so a `y ~ g` call already
names its axes: the response on the value axis and the grouping terms on
the category axis. Everything else falls back to what a box plot always
shows – groups against their distributions. `horizontal = TRUE` swaps
which visual axis is which, exactly as boxplot.formula()'s own defaults
do.

#### Usage

    BaseRBoxplotLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_formula_labels()`

Read the axis titles boxplot.formula() derives from its formula

`boxplot.formula()` builds them out of the model frame's column names:
the response column names the value axis and the remaining columns,
joined with " : ", name the category axis. Building the same model frame
reproduces the drawn titles for expressions (`log(mpg) ~ cyl`) and for
`.` alike, where deparsing the formula's terms would not.

#### Usage

    BaseRBoxplotLayerProcessor$extract_formula_labels(args, frame = NULL)

#### Arguments

- `args`:

  Recorded argument list

- `frame`:

  The model frame kept by the recording (optional)

#### Returns

List with `response` and `groups`, or NULL when this call is not the
formula method or the model frame cannot be rebuilt

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$extract_main_title()`

The main title of the recorded call, or an empty string

#### Usage

    BaseRBoxplotLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Character string

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$determine_orientation()`

Which way the boxes were drawn, from the recorded `horizontal` flag

#### Usage

    BaseRBoxplotLayerProcessor$determine_orientation(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

"horz" or "vert"

------------------------------------------------------------------------

### `BaseRBoxplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRBoxplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
