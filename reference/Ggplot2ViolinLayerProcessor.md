# Violin Layer Processor

Processes violin layers (geom_violin) to extract density curve (KDE)
data and box-summary statistics, producing two maidr layers:
`violin_kde` and `violin_box`.

The processor injects a thin `geom_boxplot(width = 0.1)` into the plot
before rendering so that the SVG contains visible box elements whose CSS
selectors can drive the violin_box highlight in the maidr frontend.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2ViolinLayerProcessor`

## Methods

### Public methods

- [`Ggplot2ViolinLayerProcessor$needs_augmentation()`](#method-Ggplot2ViolinLayerProcessor-needs_augmentation)

- [`Ggplot2ViolinLayerProcessor$augment_plot()`](#method-Ggplot2ViolinLayerProcessor-augment_plot)

- [`Ggplot2ViolinLayerProcessor$process()`](#method-Ggplot2ViolinLayerProcessor-process)

- [`Ggplot2ViolinLayerProcessor$extract_box_data()`](#method-Ggplot2ViolinLayerProcessor-extract_box_data)

- [`Ggplot2ViolinLayerProcessor$extract_kde_data()`](#method-Ggplot2ViolinLayerProcessor-extract_kde_data)

- [`Ggplot2ViolinLayerProcessor$simplify_violin_kde()`](#method-Ggplot2ViolinLayerProcessor-simplify_violin_kde)

- [`Ggplot2ViolinLayerProcessor$extract_data()`](#method-Ggplot2ViolinLayerProcessor-extract_data)

- [`Ggplot2ViolinLayerProcessor$generate_selectors()`](#method-Ggplot2ViolinLayerProcessor-generate_selectors)

- [`Ggplot2ViolinLayerProcessor$generate_box_selectors()`](#method-Ggplot2ViolinLayerProcessor-generate_box_selectors)

- [`Ggplot2ViolinLayerProcessor$determine_orientation()`](#method-Ggplot2ViolinLayerProcessor-determine_orientation)

- [`Ggplot2ViolinLayerProcessor$get_effective_mapping()`](#method-Ggplot2ViolinLayerProcessor-get_effective_mapping)

- [`Ggplot2ViolinLayerProcessor$discrete_axis_labels()`](#method-Ggplot2ViolinLayerProcessor-discrete_axis_labels)

- [`Ggplot2ViolinLayerProcessor$fill_levels_by_colour()`](#method-Ggplot2ViolinLayerProcessor-fill_levels_by_colour)

- [`Ggplot2ViolinLayerProcessor$group_labels()`](#method-Ggplot2ViolinLayerProcessor-group_labels)

- [`Ggplot2ViolinLayerProcessor$boxplot_stats()`](#method-Ggplot2ViolinLayerProcessor-boxplot_stats)

- [`Ggplot2ViolinLayerProcessor$find_boxplot_layer_index()`](#method-Ggplot2ViolinLayerProcessor-find_boxplot_layer_index)

- [`Ggplot2ViolinLayerProcessor$find_panel_grob()`](#method-Ggplot2ViolinLayerProcessor-find_panel_grob)

- [`Ggplot2ViolinLayerProcessor$find_grob_ids()`](#method-Ggplot2ViolinLayerProcessor-find_grob_ids)

- [`Ggplot2ViolinLayerProcessor$find_direct_children()`](#method-Ggplot2ViolinLayerProcessor-find_direct_children)

- [`Ggplot2ViolinLayerProcessor$find_grob_by_id()`](#method-Ggplot2ViolinLayerProcessor-find_grob_by_id)

- [`Ggplot2ViolinLayerProcessor$find_desc_by_pattern()`](#method-Ggplot2ViolinLayerProcessor-find_desc_by_pattern)

- [`Ggplot2ViolinLayerProcessor$find_all_desc_by_pattern()`](#method-Ggplot2ViolinLayerProcessor-find_all_desc_by_pattern)

- [`Ggplot2ViolinLayerProcessor$clone()`](#method-Ggplot2ViolinLayerProcessor-clone)

Inherited methods

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$needs_augmentation()`

Violin needs to inject a boxplot layer

#### Usage

    Ggplot2ViolinLayerProcessor$needs_augmentation()

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$augment_plot()`

Inject geom_boxplot into the plot for visual box + selectors

#### Usage

    Ggplot2ViolinLayerProcessor$augment_plot(plot)

#### Arguments

- `plot`:

  ggplot2 object

#### Returns

Augmented ggplot2 object with boxplot layer added

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$process()`

Process the violin layer

Returns a list with `multi_layer = TRUE` and two maidr layers:
violin_box (with BoxSelector objects) and violin_kde.

#### Usage

    Ggplot2ViolinLayerProcessor$process(
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

  The ggplot2 object (already augmented with boxplot)

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

  Panel context for faceted plots (optional)

#### Returns

List with multi_layer flag and layers, or NULL for facet panels

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$extract_box_data()`

Extract box-summary statistics per violin group

Computes min, Q1, median, Q3, max from the original data (since
geom_violin only stores the KDE curve, not quartiles).

#### Usage

    Ggplot2ViolinLayerProcessor$extract_box_data(plot, built)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

#### Returns

List of BoxPoint objects (one per violin)

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$extract_kde_data()`

Extract KDE density-curve data per violin group

Uses ggplot2's built violin data (violinwidth, x, y, width columns) to
compute left/right violin edges, applies RDP simplification to ~30
points per violin, and includes the `width` field needed by the maidr
frontend. The `svg_x`/`svg_y` coordinates are injected later by
[`create_enhanced_svg()`](https://r.maidr.ai/reference/create_enhanced_svg.md)
after the grid device is drawn.

#### Usage

    Ggplot2ViolinLayerProcessor$extract_kde_data(plot, built, max_kde_points = 30L)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `max_kde_points`:

  Maximum number of output points per violin (default 30)

#### Returns

List of lists (ViolinKdePoint\[\]\[\])

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$simplify_violin_kde()`

Simplify a single violin's KDE curve using RDP

Uses ggplot2's built violin data columns (y, violinwidth, x, width) to
compute the left/right edges, then applies RDP simplification.

#### Usage

    Ggplot2ViolinLayerProcessor$simplify_violin_kde(
      rows,
      cat_label,
      is_horizontal,
      max_points = 30L
    )

#### Arguments

- `rows`:

  data.frame of built violin data for one group

- `cat_label`:

  Character label for this violin category

- `is_horizontal`:

  Logical, TRUE for horizontal violins

- `max_points`:

  Maximum number of output points

#### Returns

List of ViolinKdePoint dicts with data_left_x/data_right_x/data_y

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$extract_data()`

Not used directly - required by base class interface

#### Usage

    Ggplot2ViolinLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$generate_selectors()`

Generate CSS selectors for violin polygons (for violin_kde layer)

#### Usage

    Ggplot2ViolinLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `grob_id`:

  Grob ID (for faceted plots)

- `panel_ctx`:

  Panel context (for faceted plots)

#### Returns

List of CSS selector strings (one per violin)

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$generate_box_selectors()`

Generate BoxSelector objects for the injected boxplot grobs

Walks the gtable to find geom_boxplot grobs and produces a BoxSelector
list (one per violin) with CSS selectors for min, iq, q2, max,
lowerOutliers, upperOutliers.

#### Usage

    Ggplot2ViolinLayerProcessor$generate_box_selectors(
      plot,
      gt,
      built,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object (augmented with boxplot)

- `gt`:

  Gtable object

- `built`:

  Built plot data

- `panel_ctx`:

  Panel context (for patchwork leaves)

#### Returns

List of BoxSelector objects

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$determine_orientation()`

Determine orientation from built data

#### Usage

    Ggplot2ViolinLayerProcessor$determine_orientation(built)

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$get_effective_mapping()`

The violin layer's mapping merged with the plot's

Built in ggplot2's own order – the layer's own aesthetics first, then
whatever only the plot maps – because the order is not cosmetic. ggplot2
numbers `group` from the interaction of a layer's discrete columns taken
in the order the mapping produced them, so a mapping assembled the other
way round gives the injected box different group ids than the violin,
and every lookup keyed on `group` then crosses the two layers.

#### Usage

    Ggplot2ViolinLayerProcessor$get_effective_mapping(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Named list of quosures, one per mapped aesthetic

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$discrete_axis_labels()`

Break labels of whichever panel axis holds the categories

The categorical axis is the discrete one, which is not always the axis
the data is keyed on:
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
leaves the data x-major while moving the category labels to the y axis,
so reading the axis off `flipped_aes` alone returns the value axis'
breaks and every violin is labelled with a number.

#### Usage

    Ggplot2ViolinLayerProcessor$discrete_axis_labels(built)

#### Arguments

- `built`:

  Built plot data

#### Returns

Character vector of labels, or NULL when neither axis is discrete (a
continuous category axis carries its value directly)

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$fill_levels_by_colour()`

Map each mapped fill colour back to the level it came from

Dodging splits one category into several violins that differ only by
fill, and they all round to the same category position. Without the
level, they are announced under one repeated name and cannot be told
apart.

#### Usage

    Ggplot2ViolinLayerProcessor$fill_levels_by_colour(built)

#### Arguments

- `built`:

  Built plot data

#### Returns

Named character vector (colour -\> level), or NULL when the plot has no
fill scale

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$group_labels()`

Announceable label for each drawn violin

#### Usage

    Ggplot2ViolinLayerProcessor$group_labels(
      built,
      layer_data,
      groups,
      is_horizontal
    )

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  Built data for the violin layer

- `groups`:

  The layer's group ids, in emission order

- `is_horizontal`:

  Whether the value axis is x

#### Returns

Character vector of labels, one per group

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$boxplot_stats()`

Box statistics ggplot2 itself computed for each group

The processor injects a
[`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)
so the SVG has box elements to highlight; that layer's `stat_boxplot`
output is also the authoritative source for the numbers to announce.
Reading it keyed by `group` avoids re-deriving quartiles from the
original data via a rounded axis position and a string match on the
break label – a round trip that silently mislabels dodged violins and
finds nothing at all under
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html).

#### Usage

    Ggplot2ViolinLayerProcessor$boxplot_stats(plot, built)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

#### Returns

data.frame of the boxplot layer's built data, or NULL

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_boxplot_layer_index()`

Find the boxplot layer index in the augmented plot

#### Usage

    Ggplot2ViolinLayerProcessor$find_boxplot_layer_index(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

Integer index of the boxplot layer, or NULL

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_panel_grob()`

Find the panel grob this layer draws into

#### Usage

    Ggplot2ViolinLayerProcessor$find_panel_grob(gt, panel_ctx = NULL)

#### Arguments

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for patchwork leaves; NULL for a single plot, where the
  panel is the cell literally named "panel"

#### Returns

The panel gTree, or NULL when it cannot be resolved

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_grob_ids()`

Recursively find all grob IDs matching a pattern

#### Usage

    Ggplot2ViolinLayerProcessor$find_grob_ids(grob, pattern)

#### Arguments

- `grob`:

  Grob tree to search

- `pattern`:

  Regular expression matched against grob names

#### Returns

Character vector of unique matching grob names

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_direct_children()`

Find direct children of a named parent matching a pattern

#### Usage

    Ggplot2ViolinLayerProcessor$find_direct_children(grob, parent_id, pattern)

#### Arguments

- `grob`:

  Grob tree to search

- `parent_id`:

  Name of the parent grob

- `pattern`:

  Regular expression matched against child names

#### Returns

Character vector of matching child names

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_grob_by_id()`

Find a grob by its name (recursive)

#### Usage

    Ggplot2ViolinLayerProcessor$find_grob_by_id(grob, target_id)

#### Arguments

- `grob`:

  Grob tree to search

- `target_id`:

  Name of the grob to find

#### Returns

The matching grob, or NULL

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_desc_by_pattern()`

Find the first descendant matching a pattern under a named parent

#### Usage

    Ggplot2ViolinLayerProcessor$find_desc_by_pattern(grob, parent_id, pattern)

#### Arguments

- `grob`:

  Grob tree to search

- `parent_id`:

  Name of the parent grob

- `pattern`:

  Regular expression matched against descendant names

#### Returns

The first matching name, or NULL

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$find_all_desc_by_pattern()`

Find all descendants matching a pattern under a named parent

#### Usage

    Ggplot2ViolinLayerProcessor$find_all_desc_by_pattern(grob, parent_id, pattern)

#### Arguments

- `grob`:

  Grob tree to search

- `parent_id`:

  Name of the parent grob

- `pattern`:

  Regular expression matched against descendant names

#### Returns

Character vector of matching descendant names

------------------------------------------------------------------------

### `Ggplot2ViolinLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2ViolinLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
