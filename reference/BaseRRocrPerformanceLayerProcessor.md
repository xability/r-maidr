# Base R ROCR Performance Layer Processor

Reads [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
ROCR `performance` object – most often
`plot(performance(pred, "prec", "rec"))`, a precision-recall curve –
from the object itself.

### Why the object and not the drawing

ROCR's `plot` method draws with calls made from inside its own
namespace: `.performance.plot.canvas()` calls
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
`type = "n"`,
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`box()`](https://rdrr.io/r/graphics/box.html), and
`.performance.plot.no.avg()` draws each curve with
[`plot.xy()`](https://rdrr.io/r/graphics/plot.xy.html) (ROCR 1.0.11).
Those resolve through ROCR's imports of graphics, never through the
search path, so maidr's wrappers see none of them; what is recorded is
the one `plot(perf)` call the reader wrote. Its `x.values` and
`y.values` are the points the method draws, after it drops the pairs
that are not finite (`ROCR:::.plot.performance`), as this does too; its
`x.name` and `y.name` are the axis titles it draws unless `xlab` and
`ylab` are given.

### The reading

ROCR names the axes of `performance(pred, "prec", "rec")` "Recall" and
"Precision", so the curve is a precision-recall curve by its own titles
([`titled_pr_curve()`](https://r.maidr.ai/reference/titled_pr_curve.md)),
as `plot(recall, precision, type = "l")` is, and is emitted as a
`pr_curve` layer whose points carry the cutoff each was scored at, from
`alpha.values`. ROCR scores its first point at an infinite cutoff, which
has no JSON number and is left out. Every other measure ROCR plots
against another – a ROC curve's rates, accuracy against cutoff – is a
line, which is what it draws.

One series per run: a `performance` object of several runs (from
cross-validation) draws one curve each, with
[`plot.xy()`](https://rdrr.io/r/graphics/plot.xy.html), and gridGraphics
names each `graphics-plot-N-lines-M`, the polylines the line processor
finds – so highlighting needs nothing new.

Only the plain drawing is read; see
[`rocr_performance_layer_type()`](https://r.maidr.ai/reference/rocr_performance_layer_type.md)
for what is declined.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRRocrPerformanceLayerProcessor`

## Methods

### Public methods

- [`BaseRRocrPerformanceLayerProcessor$process()`](#method-BaseRRocrPerformanceLayerProcessor-process)

- [`BaseRRocrPerformanceLayerProcessor$extract_data()`](#method-BaseRRocrPerformanceLayerProcessor-extract_data)

- [`BaseRRocrPerformanceLayerProcessor$extract_axis_titles()`](#method-BaseRRocrPerformanceLayerProcessor-extract_axis_titles)

- [`BaseRRocrPerformanceLayerProcessor$performance()`](#method-BaseRRocrPerformanceLayerProcessor-performance)

- [`BaseRRocrPerformanceLayerProcessor$clone()`](#method-BaseRRocrPerformanceLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$axis_extent()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-axis_extent)
- [`BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
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
- [`BaseRLineLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRRocrPerformanceLayerProcessor$process()`

Process the layer: read its curves, selectors and titles from the
recorded `performance` object

#### Usage

    BaseRRocrPerformanceLayerProcessor$process(
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

### `BaseRRocrPerformanceLayerProcessor$extract_data()`

One series per run of the `performance` object, each point its x and y
and, where it is finite, the cutoff it was scored at

#### Usage

    BaseRRocrPerformanceLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of series

------------------------------------------------------------------------

### `BaseRRocrPerformanceLayerProcessor$extract_axis_titles()`

The axis titles ROCR draws: `xlab` and `ylab` when given, else the
measures' names

#### Usage

    BaseRRocrPerformanceLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRRocrPerformanceLayerProcessor$performance()`

The recorded `performance` object

#### Usage

    BaseRRocrPerformanceLayerProcessor$performance(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

The object, or NULL when the call does not carry one

------------------------------------------------------------------------

### `BaseRRocrPerformanceLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRRocrPerformanceLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
