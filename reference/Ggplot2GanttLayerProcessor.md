# Gantt Layer Processor

Processes
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
layers that draw intervals in lanes.

A segment with the two ends of a span on one axis and a lane on the
other is how ggplot2 draws a schedule, a range plot and a high-low
chart. `ggplot_build` computes both ends and the lane exactly, so
nothing is inverted from a pixel: the four columns `x`, `xend`, `y` and
`yend` are the interval and the lane the caller wrote.

[`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
computes the same four columns and would read the same way, but is not
claimed – `gridSVG` cannot export the `curve` grob it draws, so reading
it would turn a curve chart from a static image into a
[`save_html()`](https://r.maidr.ai/reference/save_html.md) that raises.
See the adapter's own note.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2GanttLayerProcessor`

## Methods

### Public methods

- [`Ggplot2GanttLayerProcessor$process()`](#method-Ggplot2GanttLayerProcessor-process)

- [`Ggplot2GanttLayerProcessor$lane_names()`](#method-Ggplot2GanttLayerProcessor-lane_names)

- [`Ggplot2GanttLayerProcessor$extract_axes()`](#method-Ggplot2GanttLayerProcessor-extract_axes)

- [`Ggplot2GanttLayerProcessor$generate_selectors()`](#method-Ggplot2GanttLayerProcessor-generate_selectors)

- [`Ggplot2GanttLayerProcessor$target_geom_class()`](#method-Ggplot2GanttLayerProcessor-target_geom_class)

- [`Ggplot2GanttLayerProcessor$segments_grob_class()`](#method-Ggplot2GanttLayerProcessor-segments_grob_class)

- [`Ggplot2GanttLayerProcessor$find_segments_name()`](#method-Ggplot2GanttLayerProcessor-find_segments_name)

- [`Ggplot2GanttLayerProcessor$clone()`](#method-Ggplot2GanttLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_data)
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

### `Ggplot2GanttLayerProcessor$process()`

Process the gantt layer

#### Usage

    Ggplot2GanttLayerProcessor$process(
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

  Panel context for patchwork leaves and facets

#### Returns

List with data, selectors, axes and orientation

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$lane_names()`

Name the lanes, in the order the scale lays them out

Read off the panel's own view of the scale rather than off the source
column: the built data records a discrete lane as the position ggplot2
gave it (1, 2, 3), and the panel's limits are the levels in the same
order, so the two line up by index. That is also what makes an undrawn
level visible – `scale_y_discrete(drop = FALSE)` keeps it in the limits,
and it is a lane holding nothing.

NULL for a continuous lane axis, which has no names to give.

#### Usage

    Ggplot2GanttLayerProcessor$lane_names(built, lane_axis, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `lane_axis`:

  "y", "x", or NULL

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

Character vector of lane names, or NULL

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$extract_axes()`

Name the two axes

#### Usage

    Ggplot2GanttLayerProcessor$extract_axes(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

#### Returns

An axes payload with x and y

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$generate_selectors()`

Address each drawn interval by its own element

`GeomSegment` draws every interval in one `segmentsGrob`, and gridSVG
exports that as one element per segment carrying an id of the form
`<grob>.1.<n>` – measured, a four-interval chart gives
`GRID.segments.38.1.1` through `.4`, in built-data order. So an interval
is addressed by the built row it came from, and the list follows the
regrouping rather than the document.

Flat rather than nested, because the frontend slices it per lane using
the lane lengths it already has – and withdraws highlighting outright
unless the resolved count matches the interval count exactly. A partial
list is therefore worse than none, so an empty list is returned when the
grob cannot be found rather than a guess at its name.

#### Usage

    Ggplot2GanttLayerProcessor$generate_selectors(
      gt = NULL,
      plot = NULL,
      panel_ctx = NULL,
      order = integer(0)
    )

#### Arguments

- `gt`:

  Gtable object

- `plot`:

  The ggplot2 object, used to build a gtable when none is given

- `panel_ctx`:

  Panel context for patchwork leaves and facets

- `order`:

  The built-data row behind each interval, in emission order

#### Returns

A list of CSS selectors, one per interval

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$target_geom_class()`

The class of the geom this layer was drawn with

Both the grob to look for and the shape of its exported element ids
follow from it, so it is asked once and answered from the plot rather
than inferred from what happens to be in the panel.

#### Usage

    Ggplot2GanttLayerProcessor$target_geom_class(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

The geom's class name, or NULL when the layer cannot be found

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$segments_grob_class()`

Which grid grob class a segment-family geom draws

#### Usage

    Ggplot2GanttLayerProcessor$segments_grob_class(geom)

#### Arguments

- `geom`:

  The layer's geom object

#### Details

[`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
draws a `curve` grob and everything else in the family –
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html),
and
[`geom_spoke()`](https://ggplot2.tidyverse.org/reference/geom_spoke.html)
which is a `GeomSegment` subclass – draws `segments`. Asked of the geom
rather than assumed from the layer type, because it decides both which
grobs `find_segments_name()` gathers and which layers it counts itself
among, and those two have to be the same population.

#### Returns

`"curve"` or `"segments"`

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$find_segments_name()`

Find the name of the grob holding this layer's segments

The base class's `find_layer_grob_tree()` cannot serve here, and the
reason is worth recording: it matches a grob whose name begins with the
geom's own prefix, and ggplot2 does not give a segment layer one. The
grob arrives with grid's automatic name – measured, `GRID.segments.38` –
so there is no `geom_segment.` to match and the lookup returns NULL,
which is a layer that announces every interval and highlights none of
them.

The disambiguation rule is the same one that helper applies, keyed on
the grob's **class** instead: the nth segment layer of the plot draws
the nth segments grob of the panel. Two
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
layers would otherwise both resolve to the first one's elements, and the
second would highlight the first's intervals while announcing its own.

The number in that automatic name is grid's global counter and is not
stable between sessions, which is exactly why it is read off the gtable
being exported rather than reconstructed.

#### Usage

    Ggplot2GanttLayerProcessor$find_segments_name(plot, gt, panel_ctx = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

The grob name, or NULL when it cannot be resolved

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2GanttLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
