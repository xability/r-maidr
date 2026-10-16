# Base R Kaplan-Meier Layer Processor

Reads [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
[`survival::survfit`](https://rdrr.io/pkg/survival/man/survfit.html)
object – a Kaplan-Meier curve, one per stratum – from the object itself,
as a `survival` layer.

### Why the object and not the drawing

`survival:::plot.survfit()` draws from inside the survival namespace: a
`plot(type = "n")` for the frame, then one
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) per curve
of a staircase it builds itself,
[`points()`](https://r.maidr.ai/reference/base-r-wrappers.md) for the
censoring marks and two more
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) for the
confidence band (survival 3.5). Those resolve through survival's imports
of graphics, so maidr's wrappers see none of them; what is recorded is
the one `plot(fit)` call the reader wrote, which typed by `type` alone
was an empty scatter.

### The reading

One series per stratum, each point a time the object reports: the
survival estimate there, `censored` where a subject left the study at
that time without the event (`n.censor`), and the band's `yMin` and
`yMax` when the plot draws it. The curve starts where the plot starts
it, at
[`survival::survfit0()`](https://rdrr.io/pkg/survival/man/survfit0.html)'s
added origin. Times are divided by `xscale` and estimates multiplied by
`yscale`, which is how the plot's axes label them; a curve cut at `xmax`
(or at the right end of `xlim`) is cut as the plot cuts it.

Censoring is read whether or not `mark.time` draws the marks: it is part
of the estimate the curve is drawn from, not of its decoration, and it
is what separates a flat tail many subjects support from one few do.

Highlight: gridGraphics names each
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) polyline
`graphics-plot-N-lines-M` in drawing order – the curve, then its lower
and upper bound when the band is drawn – so each stratum's curve is the
first of its three, or every one without a band.

See
[`survfit_layer_type()`](https://r.maidr.ai/reference/survfit_layer_type.md)
for the drawings that are declined.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRSurvfitLayerProcessor`

## Methods

### Public methods

- [`BaseRSurvfitLayerProcessor$process()`](#method-BaseRSurvfitLayerProcessor-process)

- [`BaseRSurvfitLayerProcessor$extract_data()`](#method-BaseRSurvfitLayerProcessor-extract_data)

- [`BaseRSurvfitLayerProcessor$extract_axis_titles()`](#method-BaseRSurvfitLayerProcessor-extract_axis_titles)

- [`BaseRSurvfitLayerProcessor$generate_selectors()`](#method-BaseRSurvfitLayerProcessor-generate_selectors)

- [`BaseRSurvfitLayerProcessor$survfit()`](#method-BaseRSurvfitLayerProcessor-survfit)

- [`BaseRSurvfitLayerProcessor$clone()`](#method-BaseRSurvfitLayerProcessor-clone)

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
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)
- [`BaseRLineLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRSurvfitLayerProcessor$process()`

Process the layer: read its curves, selectors and titles from the
recorded `survfit` object

#### Usage

    BaseRSurvfitLayerProcessor$process(
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

### `BaseRSurvfitLayerProcessor$extract_data()`

One series per stratum of the recorded `survfit` object

#### Usage

    BaseRSurvfitLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

List of series

------------------------------------------------------------------------

### `BaseRSurvfitLayerProcessor$extract_axis_titles()`

The axis titles: `xlab` and `ylab` when given, else "Time" and "Survival
probability", which is what the axes hold (the plot itself titles
neither)

#### Usage

    BaseRSurvfitLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRSurvfitLayerProcessor$generate_selectors()`

One selector per stratum: the curve's own polyline, skipping the two
bound polylines drawn after it when the band is drawn. None when the
drawing has any other number of polylines – a
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) added after
the plot, say – rather than outlines on the wrong lines.

#### Usage

    BaseRSurvfitLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

- `gt`:

  Gtable of the replayed drawing (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `BaseRSurvfitLayerProcessor$survfit()`

The recorded `survfit` object

#### Usage

    BaseRSurvfitLayerProcessor$survfit(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

The object, or NULL when the call does not carry one

------------------------------------------------------------------------

### `BaseRSurvfitLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSurvfitLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
