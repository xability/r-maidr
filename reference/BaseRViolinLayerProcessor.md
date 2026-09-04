# Base R Violin Layer Processor

Reads a
[`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html)
call as the `violin_box` + `violin_kde` layer pair, matching what the
ggplot2 adapter produces for
[`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html).
Which plotting system a user chose should not decide whether their chart
is accessible.

[`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) returns
its box summary but not the density curve it drew, so both are recovered
by replaying the call vioplot makes internally — see
[`compute_vioplot_stats()`](https://r.maidr.ai/reference/compute_vioplot_stats.md),
which records why that is a transcription rather than an approximation.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRViolinLayerProcessor`

## Methods

### Public methods

- [`BaseRViolinLayerProcessor$process()`](#method-BaseRViolinLayerProcessor-process)

- [`BaseRViolinLayerProcessor$extract_violins()`](#method-BaseRViolinLayerProcessor-extract_violins)

- [`BaseRViolinLayerProcessor$build_box_data()`](#method-BaseRViolinLayerProcessor-build_box_data)

- [`BaseRViolinLayerProcessor$build_kde_data()`](#method-BaseRViolinLayerProcessor-build_kde_data)

- [`BaseRViolinLayerProcessor$build_kde_selectors()`](#method-BaseRViolinLayerProcessor-build_kde_selectors)

- [`BaseRViolinLayerProcessor$build_box_selectors()`](#method-BaseRViolinLayerProcessor-build_box_selectors)

- [`BaseRViolinLayerProcessor$grob_ids()`](#method-BaseRViolinLayerProcessor-grob_ids)

- [`BaseRViolinLayerProcessor$plot_index()`](#method-BaseRViolinLayerProcessor-plot_index)

- [`BaseRViolinLayerProcessor$extract_axis_titles()`](#method-BaseRViolinLayerProcessor-extract_axis_titles)

- [`BaseRViolinLayerProcessor$extract_main_title()`](#method-BaseRViolinLayerProcessor-extract_main_title)

- [`BaseRViolinLayerProcessor$determine_orientation()`](#method-BaseRViolinLayerProcessor-determine_orientation)

- [`BaseRViolinLayerProcessor$clone()`](#method-BaseRViolinLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_data)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_polyline_grob)
- [`LayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/LayerProcessor.html#method-generate_selectors)
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

### `BaseRViolinLayerProcessor$process()`

Read a recorded
[`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call as
two maidr layers

#### Usage

    BaseRViolinLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      layer_info = NULL
    )

#### Arguments

- `plot`:

  Unused; present for the processor interface.

- `layout`:

  Unused; present for the processor interface.

- `built`:

  Unused; present for the processor interface.

- `gt`:

  The grob tree of the rendered plot.

- `layer_info`:

  The recorded plot call and its metadata.

#### Returns

A multi-layer result, or `NULL` when nothing can be read.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$extract_violins()`

The recorded call's violins, each with its statistics

#### Usage

    BaseRViolinLayerProcessor$extract_violins(layer_info)

#### Arguments

- `layer_info`:

  The recorded plot call and its metadata.

#### Returns

A list of `list(label =, stats =)`, one per drawn violin.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$build_box_data()`

One box summary per violin

#### Usage

    BaseRViolinLayerProcessor$build_box_data(violins)

#### Arguments

- `violins`:

  As returned by `extract_violins()`.

#### Returns

A list of box points.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$build_kde_data()`

One density curve per violin

#### Usage

    BaseRViolinLayerProcessor$build_kde_data(violins)

#### Arguments

- `violins`:

  As returned by `extract_violins()`.

#### Returns

A list of point lists, one per violin.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$build_kde_selectors()`

Selectors addressing each violin's outline

#### Usage

    BaseRViolinLayerProcessor$build_kde_selectors(violins, gt, plot_index)

#### Arguments

- `violins`:

  As returned by `extract_violins()`.

- `gt`:

  The grob tree.

- `plot_index`:

  Which recorded plot these grobs belong to.

#### Returns

A list of selector strings, or an empty list.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$build_box_selectors()`

`BoxSelector` objects addressing each violin's box parts

vioplot draws the whisker, the quartile box and the median as separate
grobs, so unlike a plotly violin – where the whole box is one path and
every section has to share it – each section can point at what it
actually is.

#### Usage

    BaseRViolinLayerProcessor$build_box_selectors(violins, gt, plot_index)

#### Arguments

- `violins`:

  As returned by `extract_violins()`.

- `gt`:

  The grob tree.

- `plot_index`:

  Which recorded plot these grobs belong to.

#### Returns

A list of `BoxSelector` lists, or an empty list.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$grob_ids()`

Grob names of one kind, in drawing order

#### Usage

    BaseRViolinLayerProcessor$grob_ids(gt, plot_index, kind)

#### Arguments

- `gt`:

  The grob tree.

- `plot_index`:

  Which recorded plot these grobs belong to.

- `kind`:

  One of the kinds in `.maidr_vioplot_grob_kinds`.

#### Returns

A character vector of grob names.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$plot_index()`

Which recorded plot this layer belongs to

#### Usage

    BaseRViolinLayerProcessor$plot_index(layer_info)

#### Arguments

- `layer_info`:

  The recorded plot call and its metadata.

#### Returns

An integer index.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$extract_axis_titles()`

Axis titles for the violin's two axes

#### Usage

    BaseRViolinLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  The recorded plot call and its metadata.

#### Returns

An axes list.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$extract_main_title()`

The plot's main title

#### Usage

    BaseRViolinLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  The recorded plot call and its metadata.

#### Returns

A character scalar.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$determine_orientation()`

Whether the violins run up the page or across it

#### Usage

    BaseRViolinLayerProcessor$determine_orientation(layer_info)

#### Arguments

- `layer_info`:

  The recorded plot call and its metadata.

#### Returns

`"vert"` or `"horz"`.

------------------------------------------------------------------------

### `BaseRViolinLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRViolinLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
