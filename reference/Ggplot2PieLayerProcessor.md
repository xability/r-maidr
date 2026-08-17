# Pie Layer Processor

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

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2PieLayerProcessor`

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

- [`Ggplot2PieLayerProcessor$layer_slot_grob()`](#method-Ggplot2PieLayerProcessor-layer_slot_grob)

- [`Ggplot2PieLayerProcessor$sole_wedge_container()`](#method-Ggplot2PieLayerProcessor-sole_wedge_container)

- [`Ggplot2PieLayerProcessor$collect_polygon_grobs()`](#method-Ggplot2PieLayerProcessor-collect_polygon_grobs)

- [`Ggplot2PieLayerProcessor$find_own_polygon_grob()`](#method-Ggplot2PieLayerProcessor-find_own_polygon_grob)

- [`Ggplot2PieLayerProcessor$holds_polygon()`](#method-Ggplot2PieLayerProcessor-holds_polygon)

- [`Ggplot2PieLayerProcessor$clone()`](#method-Ggplot2PieLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### `Ggplot2PieLayerProcessor$process()`

Process the pie layer

#### Usage

    Ggplot2PieLayerProcessor$process(
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

### `Ggplot2PieLayerProcessor$extract_data()`

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

### `Ggplot2PieLayerProcessor$panel_built_data()`

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

### `Ggplot2PieLayerProcessor$resolve_slice_mapping()`

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

### `Ggplot2PieLayerProcessor$resolve_slice_labels()`

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

### `Ggplot2PieLayerProcessor$slice_categories()`

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

### `Ggplot2PieLayerProcessor$scale_labels()`

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

### `Ggplot2PieLayerProcessor$extract_pie_axes()`

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

### `Ggplot2PieLayerProcessor$generate_selectors()`

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

### `Ggplot2PieLayerProcessor$layer_slot_grob()`

The grob slot belonging to *this* layer

ggplot2 lays a panel out as the grill, a leading `zeroGrob`, **one child
per layer in layer order**, a trailing `zeroGrob` and the axis tree. So
the slot is the handle: layer *k* owns the *k*th child after the leading
blank, whether or not it drew anything.

It matters because a panel can hold more than one polar `geom_rect`
layer – two
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)s
under
[`coord_polar()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)
is an ordinary way to draw a ring over a pie – and a search that takes
the first container hands every layer the first layer's wedges. Those
selectors resolve, and the payload looks healthy, and the outline is on
the wrong marks.

`LayerProcessor$find_layer_grob_tree()` cannot be reused for this: it
matches on the geom's own class, and a
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
layer is `GeomCol` while the grob it draws is named after `geom_rect`.
Counting containers instead of slots does not work either – a
[`geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
label layer occupies a slot and draws no container, so the counts stop
lining up and both rings of an annotated pie lose their selectors.

#### Usage

    Ggplot2PieLayerProcessor$layer_slot_grob(panel)

#### Arguments

- `panel`:

  The panel grob, or NULL

#### Returns

This layer's grob, or NULL when the slot cannot be established

------------------------------------------------------------------------

### `Ggplot2PieLayerProcessor$sole_wedge_container()`

The one wedge container in a tree, when there is exactly one

The fallback for when the slot lookup cannot resolve – a panel shape
with no leading blank, or a caller handing over a gtable rather than a
panel. Correct whenever the search finds a single container, which is
every chart that is only a pie; ambiguous otherwise, and ambiguous means
no selector for the reason `generate_selectors()` gives.

#### Usage

    Ggplot2PieLayerProcessor$sole_wedge_container(roots)

#### Arguments

- `roots`:

  Grobs to search

#### Returns

Grob name, or NULL

------------------------------------------------------------------------

### `Ggplot2PieLayerProcessor$collect_polygon_grobs()`

Every wedge container in a grob tree, in drawing order

One entry per layer that drew wedges. A match is not descended into: the
container is the whole layer's wedges, and its children are the
individual ones.

#### Usage

    Ggplot2PieLayerProcessor$collect_polygon_grobs(grob)

#### Arguments

- `grob`:

  Grob to search

#### Returns

Character vector of grob names, possibly empty

------------------------------------------------------------------------

### `Ggplot2PieLayerProcessor$find_own_polygon_grob()`

Whether this grob is itself a wedge container

ggplot2 does not draw a polar bar layer the same way across versions,
and the difference is not cosmetic. Verified against real
[`gridSVG::grid.export()`](https://rdrr.io/pkg/gridSVG/man/grid.export.html)
output:

- One `geom_rect.polygon.<N>` grob holding every wedge, grouped by id.
  This is what the lookup was written for.

- A `geom_rect.gTree.<N>` holding **one `geom_polygon.polygon.<N>` grob
  per wedge**. On ggplot2 3.4.4 this is what a pie draws, and nothing
  named `geom_rect.polygon` exists anywhere in the tree – so the lookup
  found nothing, `generate_selectors()` returned an empty list, and **a
  pie highlighted nothing at all** (#151).

Either way the answer is a container whose `<polygon>` descendants are
the wedges in slice order, so the caller's descendant selector resolves
against both without knowing which it got.

The polar grill draws a polygon of its own under
[`coord_radial()`](https://ggplot2.tidyverse.org/reference/coord_radial.html),
named `GRID.polygon.<N>`; neither branch carries a name that matches it.
The gTree branch also requires a polygon to be there: a `geom_rect`
layer that drew none has nothing to point at.

#### Usage

    Ggplot2PieLayerProcessor$find_own_polygon_grob(grob)

#### Arguments

- `grob`:

  Grob to test

#### Returns

Grob name, or NULL

------------------------------------------------------------------------

### `Ggplot2PieLayerProcessor$holds_polygon()`

Whether a grob tree draws at least one polygon.

#### Usage

    Ggplot2PieLayerProcessor$holds_polygon(grob)

#### Arguments

- `grob`:

  Grob to search

#### Returns

TRUE when the tree holds a polygon grob

------------------------------------------------------------------------

### `Ggplot2PieLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PieLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
