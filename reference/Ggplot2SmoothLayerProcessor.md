# Smooth Layer Processor

Smooth Layer Processor

Smooth Layer Processor

## Details

Processes smooth plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2SmoothLayerProcessor`

## Methods

### Public methods

- [`Ggplot2SmoothLayerProcessor$process()`](#method-Ggplot2SmoothLayerProcessor-process)

- [`Ggplot2SmoothLayerProcessor$group_aes()`](#method-Ggplot2SmoothLayerProcessor-group_aes)

- [`Ggplot2SmoothLayerProcessor$attach_group_axis()`](#method-Ggplot2SmoothLayerProcessor-attach_group_axis)

- [`Ggplot2SmoothLayerProcessor$resolve_target_layer()`](#method-Ggplot2SmoothLayerProcessor-resolve_target_layer)

- [`Ggplot2SmoothLayerProcessor$layer_built_data()`](#method-Ggplot2SmoothLayerProcessor-layer_built_data)

- [`Ggplot2SmoothLayerProcessor$series_group_ids()`](#method-Ggplot2SmoothLayerProcessor-series_group_ids)

- [`Ggplot2SmoothLayerProcessor$extract_data()`](#method-Ggplot2SmoothLayerProcessor-extract_data)

- [`Ggplot2SmoothLayerProcessor$curve_points()`](#method-Ggplot2SmoothLayerProcessor-curve_points)

- [`Ggplot2SmoothLayerProcessor$generate_selectors()`](#method-Ggplot2SmoothLayerProcessor-generate_selectors)

- [`Ggplot2SmoothLayerProcessor$series_group_count()`](#method-Ggplot2SmoothLayerProcessor-series_group_count)

- [`Ggplot2SmoothLayerProcessor$grouped_curve_selectors()`](#method-Ggplot2SmoothLayerProcessor-grouped_curve_selectors)

- [`Ggplot2SmoothLayerProcessor$polyline_grob_names()`](#method-Ggplot2SmoothLayerProcessor-polyline_grob_names)

- [`Ggplot2SmoothLayerProcessor$find_layer_grob_tree()`](#method-Ggplot2SmoothLayerProcessor-find_layer_grob_tree)

- [`Ggplot2SmoothLayerProcessor$clone()`](#method-Ggplot2SmoothLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2SmoothLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `group_aes()`

Grouping aesthetics that split this layer into curves.

[`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
and
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
both render a fill, so `aes(fill = g)` splits them into one curve per
group just as `aes(colour = g)` does. The line processor probes colour
only, because a line has no fill and reading one from an unrelated
layer's mapping would invent a legend the plot never draws.

`Ggplot2Adapter` types a layer as `smooth` for `GeomSmooth` or for any
layer whose stat is `StatDensity`. A default
[`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
uses `StatAlign` and so never arrives here, but
`geom_area(stat = "density")` does, and splits per group like the
others.

#### Usage

    Ggplot2SmoothLayerProcessor$group_aes()

#### Returns

List of aesthetic-name vectors, in precedence order

------------------------------------------------------------------------

### Method `attach_group_axis()`

Add the legend title as the z axis label when the layer is split into
per-group curves.

Shared with the line layer processor via
[`attach_series_group_axis()`](https://r.maidr.ai/reference/attach_series_group_axis.md);
see `R/series_group_utils.R`.

#### Usage

    Ggplot2SmoothLayerProcessor$attach_group_axis(plot, built, data, axes)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `data`:

  The extracted layer data

- `axes`:

  Axes built so far

#### Returns

The axes list, with z added when the layer is grouped

------------------------------------------------------------------------

### Method `resolve_target_layer()`

Resolve which layer of the plot this processor describes.

Prefers this processor's OWN layer: picking the first line-like layer
would extract another layer's data in multi-layer plots (e.g.
geom_line + geom_smooth).

#### Usage

    Ggplot2SmoothLayerProcessor$resolve_target_layer(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Index into `plot$layers`

------------------------------------------------------------------------

### Method `layer_built_data()`

Built data for this layer, restricted to one facet panel.

#### Usage

    Ggplot2SmoothLayerProcessor$layer_built_data(
      plot,
      built = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A data frame of built rows

------------------------------------------------------------------------

### Method `series_group_ids()`

Distinct group ids when the layer draws more than one curve.

#### Usage

    Ggplot2SmoothLayerProcessor$series_group_ids(built_data)

#### Arguments

- `built_data`:

  Built rows for this layer

#### Returns

Sorted group ids, or an empty vector for a single-curve layer

------------------------------------------------------------------------

### Method `extract_data()`

Extract one series per drawn curve.

ggplot2 draws a mapped smooth as one curve per group, so the payload has
to be split the same way: concatenating the groups into a single series
would walk a reader off the end of one curve into the start of the next
with nothing announced in between.

#### Usage

    Ggplot2SmoothLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List of series, each a list of points

------------------------------------------------------------------------

### Method `curve_points()`

Turn built rows into MAIDR points.

#### Usage

    Ggplot2SmoothLayerProcessor$curve_points(rows, z = NULL)

#### Arguments

- `rows`:

  Built rows for one curve

- `z`:

  Series name, or NULL for a single-curve layer

#### Returns

List of points

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2SmoothLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL,
      built = NULL,
      panel_id = NULL
    )

------------------------------------------------------------------------

### Method `series_group_count()`

Number of curves this layer draws in the given panel.

Never throws: selector generation has to degrade to the single-curve
path for inputs `extract_data()` would reject.

#### Usage

    Ggplot2SmoothLayerProcessor$series_group_count(
      plot,
      built = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

Number of groups, or 0 when the layer draws a single curve

------------------------------------------------------------------------

### Method `grouped_curve_selectors()`

One selector per curve for a layer split into groups.

ggplot2 draws a grouped smooth one group at a time, so the layer's grob
tree holds an equal run of children per group: a bare polyline for
`se = FALSE`, a ribbon gTree followed by a polyline for `se = TRUE`, and
a ribbon gTree alone for
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html).
Chunking the children by group and taking the last polyline in each
chunk applies the same "the curve is the last polyline drawn" rule the
single-curve path uses, once per group instead of once per layer.

#### Usage

    Ggplot2SmoothLayerProcessor$grouped_curve_selectors(
      plot,
      gt,
      panel_ctx,
      n_series
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selector generation

- `n_series`:

  Number of curves the layer draws

#### Returns

List of selectors, or NULL when the grob tree does not line up

------------------------------------------------------------------------

### Method `polyline_grob_names()`

Names of the curve polyline grobs inside a grob, in draw order. Panel
grid lines are excluded: they are named after the theme element
(`panel.grid.major.x..polyline.N`), not `GRID.polyline.N`.

#### Usage

    Ggplot2SmoothLayerProcessor$polyline_grob_names(grob)

#### Arguments

- `grob`:

  A grob to walk

#### Returns

Character vector of grob names

------------------------------------------------------------------------

### Method `find_layer_grob_tree()`

Find the grob tree ggplot2 drew for this layer.

ggplot2 names a layer's grob after its geom (`geom_smooth.gTree.5`), so
the tree is located by that prefix and, when the plot repeats the geom,
by this layer's position among the layers sharing it. Scoping to the
layer's own tree keeps a sibling
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
polyline out of the per-group chunking.

#### Usage

    Ggplot2SmoothLayerProcessor$find_layer_grob_tree(plot, gt, panel_ctx = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selector generation

#### Returns

The matching grob, or NULL

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2SmoothLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
