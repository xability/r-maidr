# Gantt Layer Processor

Processes
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
layers that draw intervals in lanes, and
[`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md) layers
whose author declared that their rectangles do.

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

A declared rectangle layer has none of those four columns – it builds
`xmin`, `xmax`, `ymin` and `ymax` – so
[`rect_gantt_frame()`](https://r.maidr.ai/reference/rect_gantt_frame.md)
renames its bounds into them before anything here runs. That is the
whole of the rect path: the lanes, the ordering, the orientation and the
axes are then this class answering one question rather than two
implementations of it, and the processed layer comes back
[`identical()`](https://rdrr.io/r/base/identical.html) to the
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
spelling of the same schedule in everything but the grob its selectors
name. Only the lane *names* need their own route, because a rectangle
layer's lane axis is continuous and `lane_names()` reads levels off a
discrete one.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2GanttLayerProcessor`

## Methods

### Public methods

- [`Ggplot2GanttLayerProcessor$process()`](#method-Ggplot2GanttLayerProcessor-process)

- [`Ggplot2GanttLayerProcessor$lane_names()`](#method-Ggplot2GanttLayerProcessor-lane_names)

- [`Ggplot2GanttLayerProcessor$declared_lane_axis()`](#method-Ggplot2GanttLayerProcessor-declared_lane_axis)

- [`Ggplot2GanttLayerProcessor$name_rect_lanes()`](#method-Ggplot2GanttLayerProcessor-name_rect_lanes)

- [`Ggplot2GanttLayerProcessor$lane_ticks()`](#method-Ggplot2GanttLayerProcessor-lane_ticks)

- [`Ggplot2GanttLayerProcessor$extract_axes()`](#method-Ggplot2GanttLayerProcessor-extract_axes)

- [`Ggplot2GanttLayerProcessor$generate_selectors()`](#method-Ggplot2GanttLayerProcessor-generate_selectors)

- [`Ggplot2GanttLayerProcessor$target_geom_class()`](#method-Ggplot2GanttLayerProcessor-target_geom_class)

- [`Ggplot2GanttLayerProcessor$segments_grob_class()`](#method-Ggplot2GanttLayerProcessor-segments_grob_class)

- [`Ggplot2GanttLayerProcessor$find_segments_name()`](#method-Ggplot2GanttLayerProcessor-find_segments_name)

- [`Ggplot2GanttLayerProcessor$find_rect_name()`](#method-Ggplot2GanttLayerProcessor-find_rect_name)

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

### `Ggplot2GanttLayerProcessor$declared_lane_axis()`

Which axis this layer's author said the lanes run up

Read off the layer rather than inferred, because inference is not
available: measured, both axes partition for the target schedule and for
one whose tasks all take the same time, so structure can neither confirm
nor contradict what the author meant. `"y"` when nothing was declared,
which is what a
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
gantt drawn the ordinary way also reads as.

#### Usage

    Ggplot2GanttLayerProcessor$declared_lane_axis(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

`"y"` or `"x"`

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$name_rect_lanes()`

Name a rectangle gantt's lanes from the ticks inside them

`lane_names()` above cannot serve, and the reason is measured: it
requires `view$is_discrete()`, and a rectangle layer written with the
author's own numeric `ymin`/`ymax` trains a continuous scale – measured,
`is_discrete()` is FALSE and `limits` is the range `0.6, 3.4` rather
than a list of levels. The lanes are there; the scale just has no names
to lend them.

So a lane is named by the single explicit tick drawn inside it, and by
its position otherwise – the rule xability/py-maidr#533 settled. Two
guards come with it and both are that issue's: a band holding more than
one tick is named by none of them, and a band holding none is named by
its position.

Read off `built$layout$panel_params`, never
[`layer_scales()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html):
measured on the default scale the panel's view gives breaks
`NA, 1, 2, 3, NA` while
[`layer_scales()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
gives `NA, 1, 1.5, 2, 2.5, 3, NA` – two ticks per band, which defeats
the one-tick rule in exactly the case the rule exists for. The `NA`
padding is dropped.

#### Usage

    Ggplot2GanttLayerProcessor$name_rect_lanes(
      grouped,
      built,
      built_data,
      lane_axis,
      panel_id = NULL
    )

#### Arguments

- `grouped`:

  The lanes as
  [`segment_lanes()`](https://r.maidr.ai/reference/segment_lanes.md)
  grouped them

- `built`:

  Built plot data

- `built_data`:

  The normalised frame, carrying the bounds and the lane

- `lane_axis`:

  "y", "x", or NULL

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

`grouped` with its named lanes renamed

------------------------------------------------------------------------

### `Ggplot2GanttLayerProcessor$lane_ticks()`

The lane axis's drawn ticks, with the padding dropped

`panel_params` is keyed by the axis the chart *draws*, not the axis the
data lives on, and
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
swaps the two. So the panel is asked for the drawn counterpart of
`lane_axis` rather than for `lane_axis` itself.

Indexing by `lane_axis` reads the span axis under a flip, and the wrong
answer is worth writing down because it is two different wrong answers.
Measured on ggplot2 3.4.4, the example schedule with
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
added: with the time axis given its own named breaks the lanes came back
`Jan, Feb, Mar` – names the chart draws along the other axis – and with
the ordinary numeric time breaks `0, 5, 10, 15` every label failed
[`label_names_its_lane()`](https://r.maidr.ai/reference/label_names_its_lane.md)
and the lanes silently lost their names altogether, on a chart drawing
`design, build, test`. Both are pinned in
`tests/testthat/test-gantt-rect.R`.

The breaks travel with the labels, so they stay comparable with the
bands: measured under the flip, `panel_params[[1]]$x` gives breaks
`1, 2, 3` against bands `0.6-1.4`, `1.6-2.4` and `2.6-3.4`, which are
data-space `ymin`/`ymax`.

`class()[1]` is `"CoordFlip"` here – measured – but the test is
[`inherits()`](https://rdrr.io/r/base/class.html), because it is asking
whether the coord flips rather than which coord it is.

`lane_names()` above indexes by `lane_axis` too and is deliberately left
alone: it requires `view$is_discrete()`, a rectangle layer's numeric
bounds always train a continuous lane axis, and so it cannot reach a
rect gantt at all. Measured, the
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
spelling of the same flipped chart comes back with no `lanes` rather
than with borrowed ones, which is the reading it has today and not this
issue's to change.

#### Usage

    Ggplot2GanttLayerProcessor$lane_ticks(built, lane_axis, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `lane_axis`:

  "y", "x", or NULL

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of `breaks` and `labels`, or NULL

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

### `Ggplot2GanttLayerProcessor$find_rect_name()`

Find the name of the grob holding a rect layer's bars

The opposite way round from `find_segments_name()`, and for a measured
reason: a rectangle layer *is* given a geom-prefixed grob name, and the
grob class is useless because the theme draws rects too. Collecting
every `rect`-class grob of a lone rect chart gave, in tree order,


      plot.background..rect.33  panel.background..rect.6  geom_rect.rect.2
      

so position 1 is the plot background and the reader would have the whole
page highlighted for their first task. The name prefix `^geom_rect\.`
matches the drawn bars and none of the theme's rects.

Every number in a grob name here is grid's global counter, which
`find_segments_name()` above already records as not stable between
sessions – the same chart measured second in a session numbers higher.
What was measured is the tree order and the rect counts; each listing
below is from its own fresh session.

The counter is the other half. ggplot2 names a drawn grob after the geom
whose `draw_panel()` made it, and `GeomRect$ draw_panel()` hard-codes
`geom_rect`, so
[`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html),
[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
and
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
all emit `geom_rect.rect.*` grobs while
[`geom_grob_prefix()`](https://r.maidr.ai/reference/geom_grob_prefix.md)
calls them `geom_tile`/`geom_bar`/`geom_col`. Measured,
`geom_col(5 bars) + geom_rect(4 rects)` draws two of them –
`geom_rect.rect.2` holding the 5 bars and `geom_rect.rect.4` holding the
4 bands – and the base class's `find_layer_grob_tree()` hands the rect
layer the first, the column chart's bars. Counting the target among
`inherits(geom, "GeomRect")` layers makes the counted population the
drawn population and resolves it to the second; measured the same for
`geom_tile(9) + geom_rect(4)`, which draws 9 then 4 under the same two
names.

[`inherits()`](https://rdrr.io/r/base/class.html) rather than a
written-out list of class names, so that a rect subclass this package
has never heard of is counted as what it draws. Measured, `GeomTile`,
`GeomBar` and `GeomCol` all inherit `GeomRect`; `GeomRaster` does not,
and draws `GRID.rastergrob.*` rather than a rect, so the two populations
agree on it as well. `GeomRectCS`, the candlestick body, inherits it too
– measured against tidyquant 1.0.12, where
`inherits(GeomRectCS, "GeomRect")` is TRUE and `class(GeomRectCS)[1]` is
`"GeomRectCS"`.

Scoped to this lookup. The same miscount reaches any bar, heat or
candlestick layer sharing a panel with another rect-drawn geom through
`find_layer_grob_tree()`; that is a defect this change did not introduce
and does not widen.

#### Usage

    Ggplot2GanttLayerProcessor$find_rect_name(
      plot,
      gt,
      panel_ctx = NULL,
      target = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for patchwork leaves and facets

- `target`:

  This layer's index among the plot's layers

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
