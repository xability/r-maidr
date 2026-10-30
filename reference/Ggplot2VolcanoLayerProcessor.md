# Volcano and Manhattan Layer Processor

Reads a
[`maidr_volcano()`](https://r.maidr.ai/reference/maidr_volcano.md) or
[`maidr_manhattan()`](https://r.maidr.ai/reference/maidr_manhattan.md)
layer as the `volcano` or `manhattan` trace. Both are scatters, so the
point processor does the work: the drawn rows, the positions read back
through the scales, the selector for the panel's points. What this adds
is what the trace reads that a scatter does not.

- **Each point's identity.** The geom's `label` and `region` aesthetics
  survive the build as columns, and are emitted as the point's `label`
  and `group` (the grammar's name for the region a point belongs to).

- **The threshold.** The layer's declared `thresholdOptions`, which the
  core reads beside `data`, in the units the points are announced in.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2PointLayerProcessor`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.md)
-\> `Ggplot2VolcanoLayerProcessor`

## Methods

### Public methods

- [`Ggplot2VolcanoLayerProcessor$process()`](#method-Ggplot2VolcanoLayerProcessor-process)

- [`Ggplot2VolcanoLayerProcessor$attach_identities()`](#method-Ggplot2VolcanoLayerProcessor-attach_identities)

- [`Ggplot2VolcanoLayerProcessor$clone()`](#method-Ggplot2VolcanoLayerProcessor-clone)

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
- [`Ggplot2PointLayerProcessor$colour_group_layers()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-colour_group_layers)
- [`Ggplot2PointLayerProcessor$extract_axes_labels()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axes_labels)
- [`Ggplot2PointLayerProcessor$extract_axis_grid_info()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axis_grid_info)
- [`Ggplot2PointLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_data)
- [`Ggplot2PointLayerProcessor$find_children_by_type()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_children_by_type)
- [`Ggplot2PointLayerProcessor$find_panel_grob()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_panel_grob)
- [`Ggplot2PointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-generate_selectors)

------------------------------------------------------------------------

### `Ggplot2VolcanoLayerProcessor$process()`

Process the volcano or Manhattan layer

#### Usage

    Ggplot2VolcanoLayerProcessor$process(
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

List with data, selectors, axes, type and thresholdOptions

------------------------------------------------------------------------

### `Ggplot2VolcanoLayerProcessor$attach_identities()`

Attach each point's `label` and `group`

The point processor emits one point per drawn row: the panel's rows,
less those whose x or y is missing. The same filter over the same built
rows puts each label and region back beside its point. Should the counts
ever disagree, no identity is attached rather than the wrong one.

#### Usage

    Ggplot2VolcanoLayerProcessor$attach_identities(
      data,
      plot,
      built,
      panel_id = NULL
    )

#### Arguments

- `data`:

  The points the point processor emitted

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The points, with `label` and `group` where the layer has them

------------------------------------------------------------------------

### `Ggplot2VolcanoLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2VolcanoLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
