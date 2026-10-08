# Percentile Band Layer Processor

Reads a fan of nested quantile intervals around a median – the
`stat_lineribbon()` / `geom_lineribbon()` of ggdist – as the
`percentile_band` trace: at each x, the distribution's quantiles, which
a reader enters on the median and walks up and down band by band, each
announced as the band it bounds ("Middle 80% is 1.2 to 3.4").

Until this, a lineribbon matched no branch of the adapter, and an unread
layer drops the whole chart to a static image.

**What is read.** ggdist draws one ribbon per interval width and the
median line over them. A ribbon of width `w` spans the quantiles
`(1 - w) / 2` and `(1 + w) / 2`, and the line is the quantile `0.5` –
which holds only for a median with quantile intervals (`median_qi()`,
`stat_lineribbon()`'s default). A mean, or a highest-density interval,
is not a quantile, and
[`lineribbon_quantile_rows()`](https://r.maidr.ai/reference/lineribbon_quantile_rows.md)
declines the layer before it reaches this processor.

**Selectors.** One per band, outermost first, then the median line: the
shape the core reads as "one element per band". ggdist draws its ribbons
widest first, so the draw order of the band polygons is already the
order asked for; a count that disagrees with the widths emits no
selectors rather than mispaired ones.

**A `median_hilow` ribbon.**
`stat_summary(geom = "ribbon", fun.data = median_hilow)` is a band of
one width, `fun.args$conf.int`, around the median the stat computed, and
is read the same way from
[`summary_band_rows()`](https://r.maidr.ai/reference/summary_band_rows.md).
Its selectors are the ribbon's one polygon and, when a
[`stat_summary()`](https://ggplot2.tidyverse.org/reference/stat_summary.html)
median line sits on it, that line's polyline; the line layer itself is
skipped, its values being the band's median.

Emitted with `type = "percentile_band"`, which the core has read since
maidr 4.14.0.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2LineLayerProcessor`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.md)
-\>
[`Ggplot2AreaLayerProcessor`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.md)
-\> `Ggplot2PercentileBandLayerProcessor`

## Methods

### Public methods

- [`Ggplot2PercentileBandLayerProcessor$process()`](#method-Ggplot2PercentileBandLayerProcessor-process)

- [`Ggplot2PercentileBandLayerProcessor$quantile_points()`](#method-Ggplot2PercentileBandLayerProcessor-quantile_points)

- [`Ggplot2PercentileBandLayerProcessor$band_selectors()`](#method-Ggplot2PercentileBandLayerProcessor-band_selectors)

- [`Ggplot2PercentileBandLayerProcessor$summary_band_selectors()`](#method-Ggplot2PercentileBandLayerProcessor-summary_band_selectors)

- [`Ggplot2PercentileBandLayerProcessor$clone()`](#method-Ggplot2PercentileBandLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
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
- [`Ggplot2LineLayerProcessor$attach_discrete_y_names()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_discrete_y_names)
- [`Ggplot2LineLayerProcessor$attach_group_axis()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_group_axis)
- [`Ggplot2LineLayerProcessor$attach_level_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-attach_level_labels)
- [`Ggplot2LineLayerProcessor$build_level_lookup()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-build_level_lookup)
- [`Ggplot2LineLayerProcessor$curve_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-curve_selectors)
- [`Ggplot2LineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_data)
- [`Ggplot2LineLayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_layer_axes)
- [`Ggplot2LineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_multiline_data)
- [`Ggplot2LineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-extract_single_line_data)
- [`Ggplot2LineLayerProcessor$find_main_polyline_grob()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-find_main_polyline_grob)
- [`Ggplot2LineLayerProcessor$format_x_value()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-format_x_value)
- [`Ggplot2LineLayerProcessor$generate_multiline_selectors()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_multiline_selectors)
- [`Ggplot2LineLayerProcessor$generate_single_line_selector()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-generate_single_line_selector)
- [`Ggplot2LineLayerProcessor$get_group_column()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_group_column)
- [`Ggplot2LineLayerProcessor$get_layer()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_layer)
- [`Ggplot2LineLayerProcessor$get_x_transformation()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-get_x_transformation)
- [`Ggplot2LineLayerProcessor$has_series_groups()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-has_series_groups)
- [`Ggplot2LineLayerProcessor$line_layer_position()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-line_layer_position)
- [`Ggplot2LineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-needs_reordering)
- [`Ggplot2LineLayerProcessor$normalize_point_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-normalize_point_values)
- [`Ggplot2LineLayerProcessor$panel_axis_labels()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-panel_axis_labels)
- [`Ggplot2LineLayerProcessor$polyline_curve_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-polyline_curve_count)
- [`Ggplot2LineLayerProcessor$recover_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-recover_x_values)
- [`Ggplot2LineLayerProcessor$resolve_group_mapping()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-resolve_group_mapping)
- [`Ggplot2LineLayerProcessor$series_count()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-series_count)
- [`Ggplot2LineLayerProcessor$transform_x_values()`](https://r.maidr.ai/reference/Ggplot2LineLayerProcessor.html#method-transform_x_values)
- [`Ggplot2AreaLayerProcessor$attach_fill_axis()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-attach_fill_axis)
- [`Ggplot2AreaLayerProcessor$band_height()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-band_height)
- [`Ggplot2AreaLayerProcessor$band_polygon_names()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-band_polygon_names)
- [`Ggplot2AreaLayerProcessor$drop_alignment_vertices()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-drop_alignment_vertices)
- [`Ggplot2AreaLayerProcessor$extract_series()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-extract_series)
- [`Ggplot2AreaLayerProcessor$fill_levels()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-fill_levels)
- [`Ggplot2AreaLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-generate_selectors)
- [`Ggplot2AreaLayerProcessor$mapped_column()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-mapped_column)
- [`Ggplot2AreaLayerProcessor$resolve_area_type()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-resolve_area_type)
- [`Ggplot2AreaLayerProcessor$resolve_series_labels()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-resolve_series_labels)
- [`Ggplot2AreaLayerProcessor$scalar()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-scalar)
- [`Ggplot2AreaLayerProcessor$source_x_values()`](https://r.maidr.ai/reference/Ggplot2AreaLayerProcessor.html#method-source_x_values)

------------------------------------------------------------------------

### `Ggplot2PercentileBandLayerProcessor$process()`

Process the lineribbon layer

#### Usage

    Ggplot2PercentileBandLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
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

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data, selectors, title, axes and type

------------------------------------------------------------------------

### `Ggplot2PercentileBandLayerProcessor$quantile_points()`

The quantiles at each x

#### Usage

    Ggplot2PercentileBandLayerProcessor$quantile_points(
      rows,
      built,
      panel_id = NULL
    )

#### Arguments

- `rows`:

  The layer's rows: `x`, `y` (the median), `ymin`, `ymax` and `.width`

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of `{x, quantiles: [{level, value}]}`, by x

------------------------------------------------------------------------

### `Ggplot2PercentileBandLayerProcessor$band_selectors()`

One selector per band, outermost first, then the median line's

#### Usage

    Ggplot2PercentileBandLayerProcessor$band_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL,
      n_bands = 0L
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selector generation

- `n_bands`:

  How many interval widths the data holds

#### Returns

A list of selectors, or an empty list

------------------------------------------------------------------------

### `Ggplot2PercentileBandLayerProcessor$summary_band_selectors()`

The selectors of a `median_hilow` ribbon: its one band, then the median
line drawn on it, when there is one

The ribbon is drawn as one polygon, and the median line as the bare
polyline
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
draws, found the way the line processor finds its own. Without the line
the core outlines the band for the median, the band it sits inside.

#### Usage

    Ggplot2PercentileBandLayerProcessor$summary_band_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL,
      n_bands = 0L,
      median_line = NA_integer_
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selector generation

- `n_bands`:

  How many interval widths the data holds

- `median_line`:

  Index of the median line's layer, or NA

#### Returns

A list of selectors, or an empty list

------------------------------------------------------------------------

### `Ggplot2PercentileBandLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PercentileBandLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
