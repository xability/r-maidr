# Pie Layer Processor

Pie Layer Processor

Pie Layer Processor

## Details

Processes the ggplot2 idiom for a pie chart: a
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html) /
[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
layer drawn in polar coordinates with theta mapped to y, so the stack's
segments become wedges. The payload is 1-D and flat – one point per
wedge, `x` the slice label and `y` its magnitude. The percentage MAIDR
announces is derived from those values by the frontend, so this layer
deliberately does not emit one.

Multi-ring "bullseye" polar bars are out of scope.
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
with a non-constant x under `coord_polar("y")` draws one concentric ring
per x category, and a flat list of wedges cannot carry that second
dimension – wedges from different rings would collapse onto the same
label. Those layers never reach this processor:
`Ggplot2Adapter$is_pie_coord()` declines them, and they stay bar /
stacked / dodged as before.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2PieLayerProcessor`

## Methods

### Public methods

- [`Ggplot2PieLayerProcessor$process()`](#method-Ggplot2PieLayerProcessor-process)

- [`Ggplot2PieLayerProcessor$extract_data()`](#method-Ggplot2PieLayerProcessor-extract_data)

- [`Ggplot2PieLayerProcessor$panel_built_data()`](#method-Ggplot2PieLayerProcessor-panel_built_data)

- [`Ggplot2PieLayerProcessor$resolve_slice_mapping()`](#method-Ggplot2PieLayerProcessor-resolve_slice_mapping)

- [`Ggplot2PieLayerProcessor$resolve_slice_labels()`](#method-Ggplot2PieLayerProcessor-resolve_slice_labels)

- [`Ggplot2PieLayerProcessor$slice_categories()`](#method-Ggplot2PieLayerProcessor-slice_categories)

- [`Ggplot2PieLayerProcessor$scale_labels()`](#method-Ggplot2PieLayerProcessor-scale_labels)

- [`Ggplot2PieLayerProcessor$extract_pie_axes()`](#method-Ggplot2PieLayerProcessor-extract_pie_axes)

- [`Ggplot2PieLayerProcessor$generate_selectors()`](#method-Ggplot2PieLayerProcessor-generate_selectors)

- [`Ggplot2PieLayerProcessor$find_polygon_grob()`](#method-Ggplot2PieLayerProcessor-find_polygon_grob)

- [`Ggplot2PieLayerProcessor$clone()`](#method-Ggplot2PieLayerProcessor-clone)

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

Process the pie layer

#### Usage

    Ggplot2PieLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
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

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data, selectors, title, axes and type

------------------------------------------------------------------------

### Method `extract_data()`

Extract one point per wedge

The magnitude is the segment's own extent, not the stacked `y`:
`ymax - ymin` is what the wedge actually subtends, and it is the one
expression that works for both
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
(stat identity) and
[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
(stat count).

The extent is unsigned, though, and a negative datum is stacked *below*
the baseline: ggplot2 builds `v = -40` as `ymin = -40, ymax = 0`, so the
extent is 40 and the sign is gone. Reporting that would announce a slice
the author entered as -40 as `40`, and compute its share against a total
that swallowed it – confidently wrong, and indistinguishable from real
data.

So the sign is restored from which side of the baseline the segment sits
on. The renderer treats a negative slice as a gap, announcing it as
missing rather than letting it corrupt every other slice's percentage;
laundering it here would leave that defence nothing to catch. Whether a
producer should reject such a value outright is a separate question –
see xability/maidr#771 – but no answer to it is served by destroying the
sign first.

#### Usage

    Ggplot2PieLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Optional facet panel to restrict extraction to

#### Returns

List of `list(x, y)` points, one per wedge

------------------------------------------------------------------------

### Method `panel_built_data()`

Rows of this layer's built data, optionally one panel's

#### Usage

    Ggplot2PieLayerProcessor$panel_built_data(built, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `panel_id`:

  Optional facet panel to restrict the rows to

#### Returns

data.frame of built rows for this layer

------------------------------------------------------------------------

### Method `resolve_slice_mapping()`

Resolve the aesthetic whose categories name the wedges

Fill is probed before x because the idiomatic pie maps x to the literal
`""` and carries the categories on fill. A layer whose built rows do not
each sit in their own group is not split by any aesthetic (every row
shares group -1 or 1), so no aesthetic names its wedges.

#### Usage

    Ggplot2PieLayerProcessor$resolve_slice_mapping(plot, built_data)

#### Arguments

- `plot`:

  The ggplot2 object

- `built_data`:

  This layer's built rows

#### Returns

list with `aes` (aesthetic name, or NULL) and `column` (the mapped
column name)

------------------------------------------------------------------------

### Method `resolve_slice_labels()`

Name each wedge after the category it draws

[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
has already replaced the grouping column with integer group ids,
assigned in the sorted order of that column's values – the same order
the scale reports its labels in. Indexing the labels BY the id, rather
than by position among the ids present, is what stops a facet panel that
is missing a category from shifting every remaining wedge's label by
one. Wedges the scale cannot name fall back to their position.

#### Usage

    Ggplot2PieLayerProcessor$resolve_slice_labels(plot, built, built_data)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `built_data`:

  This layer's built rows

#### Returns

Character vector, one label per wedge

------------------------------------------------------------------------

### Method `slice_categories()`

Categories of the aesthetic that splits the wedges

The scale is asked first, because a mapping written as an expression –
`aes(fill = factor(cyl))` – has no column to read. A discrete POSITION
scale keeps its labels in `panel_params` instead, and
[`coord_polar()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)
publishes none of those under x, so the mapped column is the fallback.
Both list the categories in the same sorted order the group ids were
assigned in.

#### Usage

    Ggplot2PieLayerProcessor$slice_categories(plot, built, slice)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `slice`:

  Slice mapping from `resolve_slice_mapping()`

#### Returns

Character vector of categories, or NULL when neither source has any

------------------------------------------------------------------------

### Method `scale_labels()`

Break labels of the scale backing an aesthetic

#### Usage

    Ggplot2PieLayerProcessor$scale_labels(built, aes_name)

#### Arguments

- `built`:

  Built plot data

- `aes_name`:

  Aesthetic whose scale to read

#### Returns

Character vector of labels, or NULL when the scale has none

------------------------------------------------------------------------

### Method `extract_pie_axes()`

Build the canonical axes for a pie layer

`x` names what the wedge labels mean and `y` what their magnitudes
measure. Since the labels come off the slice aesthetic, its legend title
is the x label – resolved the same way the stacked bar layer resolves
its z label. The y label is taken from the layout, which reads the BUILT
plot's labels and so already carries a stat-derived name such as
"count".

#### Usage

    Ggplot2PieLayerProcessor$extract_pie_axes(plot, layout, built, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data

- `panel_id`:

  Optional facet panel to restrict extraction to

#### Returns

Canonical axes list with x and y

------------------------------------------------------------------------

### Method `generate_selectors()`

Generate the wedge selector for this layer

In polar coordinates the whole layer is ONE `polygonGrob` named
`geom_rect.polygon.<N>` whose sub-polygons are grouped by `id` – not the
`geom_rect.rect.<N>` a cartesian bar layer draws. gridSVG exports it as
`<g id="geom_rect.polygon.<N>.1">` with one `<polygon>` child per wedge,
emitted in built-row order, so a single descendant selector resolves to
the N elements in slice order.

#### Usage

    Ggplot2PieLayerProcessor$generate_selectors(plot, gt = NULL, panel_ctx = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List holding one selector, or an empty list

------------------------------------------------------------------------

### Method `find_polygon_grob()`

Find this layer's wedge polygon grob within a grob tree

Matches on the `geom_rect.polygon` prefix, which the polar grill's own
polygon (named `GRID.polygon.<N>` under
[`coord_radial()`](https://ggplot2.tidyverse.org/reference/coord_radial.html))
does not carry.

#### Usage

    Ggplot2PieLayerProcessor$find_polygon_grob(grob)

#### Arguments

- `grob`:

  Grob to search

#### Returns

Grob name, or NULL when the tree holds none

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PieLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
