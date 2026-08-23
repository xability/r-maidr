# ggplot2 System Adapter

Adapter for the ggplot2 plotting system. This adapter wraps the existing
ggplot2 functionality to work with the new extensible architecture.

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`SystemAdapter`](https://r.maidr.ai/reference/SystemAdapter.md) -\>
`Ggplot2Adapter`

## Methods

### Public methods

- [`Ggplot2Adapter$new()`](#method-Ggplot2Adapter-initialize)

- [`Ggplot2Adapter$can_handle()`](#method-Ggplot2Adapter-can_handle)

- [`Ggplot2Adapter$detect_layer_type()`](#method-Ggplot2Adapter-detect_layer_type)

- [`Ggplot2Adapter$is_pie_coord()`](#method-Ggplot2Adapter-is_pie_coord)

- [`Ggplot2Adapter$draws_single_ring()`](#method-Ggplot2Adapter-draws_single_ring)

- [`Ggplot2Adapter$find_layer_index()`](#method-Ggplot2Adapter-find_layer_index)

- [`Ggplot2Adapter$create_orchestrator()`](#method-Ggplot2Adapter-create_orchestrator)

- [`Ggplot2Adapter$get_system_name()`](#method-Ggplot2Adapter-get_system_name)

- [`Ggplot2Adapter$get_adapter()`](#method-Ggplot2Adapter-get_adapter)

- [`Ggplot2Adapter$has_facets()`](#method-Ggplot2Adapter-has_facets)

- [`Ggplot2Adapter$is_patchwork()`](#method-Ggplot2Adapter-is_patchwork)

- [`Ggplot2Adapter$ribbon_is_area()`](#method-Ggplot2Adapter-ribbon_is_area)

- [`Ggplot2Adapter$segments_span_lanes()`](#method-Ggplot2Adapter-segments_span_lanes)

- [`Ggplot2Adapter$unread_layer_type()`](#method-Ggplot2Adapter-unread_layer_type)

- [`Ggplot2Adapter$clone()`](#method-Ggplot2Adapter-clone)

------------------------------------------------------------------------

### `Ggplot2Adapter$new()`

Initialize the ggplot2 adapter

#### Usage

    Ggplot2Adapter$new()

------------------------------------------------------------------------

### `Ggplot2Adapter$can_handle()`

Check if this adapter can handle a plot object

#### Usage

    Ggplot2Adapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE if this adapter can handle the object, FALSE otherwise

------------------------------------------------------------------------

### `Ggplot2Adapter$detect_layer_type()`

Detect the type of a single layer

#### Usage

    Ggplot2Adapter$detect_layer_type(layer, plot_object)

#### Arguments

- `layer`:

  The ggplot2 layer object to analyze

- `plot_object`:

  The parent plot object (for context)

#### Returns

String indicating the layer type (e.g., "bar", "line", "point")

------------------------------------------------------------------------

### `Ggplot2Adapter$is_pie_coord()`

Check if a bar layer is drawn as pie wedges

[`coord_radial()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)
produces a CoordRadial that does NOT inherit CoordPolar, so both class
names have to be tested. `theta` decides what the angle encodes: only
`theta = "y"` maps a bar's height onto the angle, which is a pie.
`theta = "x"` keeps the height on the radius, which is a coxcomb/rose -
still a bar chart, just bent.

The coordinate system alone is not enough: a polar bar layer is a pie
only when it draws ONE ring. `geom_col(aes(x = category))` under
`coord_polar("y")` draws one concentric ring per x category - a
bullseye - and a pie payload has no room for that second dimension, so
such a layer keeps the bar classification it has always had.

#### Usage

    Ggplot2Adapter$is_pie_coord(plot_object, layer = NULL)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

- `layer`:

  The layer being classified, or NULL for the plot's first

#### Returns

TRUE when the layer is drawn as a pie, FALSE otherwise

------------------------------------------------------------------------

### `Ggplot2Adapter$draws_single_ring()`

Check if a layer occupies a single position on x

The ring count has to come off the BUILT data: a mapping expression
cannot say how many levels it has, and by build time ggplot2 has already
resolved every constant form - the literal `""`, a one-level factor, a
column holding one repeated value - to the same single x position. Each
facet panel is its own pie, so constancy is asked of each panel
separately. A build that fails answers FALSE, leaving the layer
classified the way it was before pie support.

#### Usage

    Ggplot2Adapter$draws_single_ring(plot_object, layer = NULL)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

- `layer`:

  The layer being classified, or NULL for the plot's first

#### Returns

TRUE when no panel holds more than one x position

------------------------------------------------------------------------

### `Ggplot2Adapter$find_layer_index()`

Locate a layer among its plot's layers

#### Usage

    Ggplot2Adapter$find_layer_index(plot_object, layer = NULL)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

- `layer`:

  The layer to locate, or NULL for the plot's first

#### Returns

Integer index into the plot's layers, or NULL when absent

------------------------------------------------------------------------

### `Ggplot2Adapter$create_orchestrator()`

Create an orchestrator for this system (ggplot2)

#### Usage

    Ggplot2Adapter$create_orchestrator(plot_object)

#### Arguments

- `plot_object`:

  The ggplot2 plot object to process

#### Returns

PlotOrchestrator instance

------------------------------------------------------------------------

### `Ggplot2Adapter$get_system_name()`

Get the system name

#### Usage

    Ggplot2Adapter$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `Ggplot2Adapter$get_adapter()`

Get a reference to this adapter (for use by orchestrator)

#### Usage

    Ggplot2Adapter$get_adapter()

#### Returns

Self reference

------------------------------------------------------------------------

### `Ggplot2Adapter$has_facets()`

Check if plot has facets

#### Usage

    Ggplot2Adapter$has_facets(plot_object)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

#### Returns

TRUE if plot has facets, FALSE otherwise

------------------------------------------------------------------------

### `Ggplot2Adapter$is_patchwork()`

Check if plot is a patchwork plot

#### Usage

    Ggplot2Adapter$is_patchwork(plot_object)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

#### Returns

TRUE if plot is patchwork, FALSE otherwise

------------------------------------------------------------------------

### `Ggplot2Adapter$ribbon_is_area()`

Whether a ribbon fills from a baseline rather than spanning two curves.

`geom_ribbon(aes(ymin = 0, ymax = y))` is an area chart: the magnitude
is the height of the fill, measured from a baseline the reader can
assume. `geom_ribbon(aes(ymin = lo, ymax = hi))` draws the *gap*, and
its content is the distance between two edges rather than the height of
either – read as an area it would announce `hi` as a magnitude and drop
`lo` entirely.

The same distinction the Python binding draws for `fill_between()`, and
drawn the same way: only an identically-zero lower edge is an area.

Reads the built data rather than the mapping, because `ymin` may be a
constant, a column, or a computed aesthetic, and only the built frame
has resolved which. A layer that cannot be built is treated as a band,
which is the reading that loses nothing: an area announced as an
interval still carries both edges.

#### Usage

    Ggplot2Adapter$ribbon_is_area(layer, plot_object)

#### Arguments

- `layer`:

  The ggplot2 layer

- `plot_object`:

  The parent plot object

#### Returns

TRUE when the ribbon is an area chart

------------------------------------------------------------------------

### `Ggplot2Adapter$segments_span_lanes()`

Check whether a segment layer draws intervals in lanes

Asked of the built data for the reason `ribbon_is_area()` is: a mapping
expression cannot say whether the two ends of a segment agree, and by
build time ggplot2 has resolved every spelling of the lane – a factor, a
character column, a repeated constant – to the position it drew at.

The whole layer is asked at once rather than each row, which is the rule
xability/maidr#1100 settled for the same reading: one
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
call can hold spans and edges together, and reading three spans out of
four segments would announce a gantt quietly missing a quarter of its
chart.

#### Usage

    Ggplot2Adapter$segments_span_lanes(layer, plot_object)

#### Arguments

- `layer`:

  The layer being classified

- `plot_object`:

  The ggplot2 plot object

#### Returns

TRUE when the layer's segments lay intervals in lanes

------------------------------------------------------------------------

### `Ggplot2Adapter$unread_layer_type()`

The answer for a layer no branch above claimed

`"unknown"` is what makes `has_unsupported_layers()` true and drops the
whole plot to a static image. That is right for a layer carrying marks
nothing describes: a filled
[`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
is drawn, and a reader told the chart was complete would be told wrong.

It is not right for a layer that drew nothing. Then there is no mark, so
there is nothing the reader is missing, and the chart pays everything to
protect them from an absence. Measured with
[`save_html()`](https://r.maidr.ai/reference/save_html.md) on thirty
points:


    geom_point()                                interactive   50,406 bytes
    geom_point() + geom_point(data = d[0, ])    interactive   51,313 bytes
    geom_point() + geom_polygon(data = d[0, ])  base64 image  27,368 bytes
    geom_point() + geom_polygon()               base64 image  31,848 bytes

Rows two and three are the same chart in every way a reader could tell –
thirty points and a layer of nothing – and only one of them was
interactive, because its empty layer happened to be of a *kind* this
function names. Row four is the case the fallback exists for, and it
keeps falling back.

The case this turns up in is not contrived: a missing **Suggests**
package.
[`geom_quantile()`](https://ggplot2.tidyverse.org/reference/geom_quantile.html)
without quantreg warns, computes no rows and draws nothing; ggplot2
carries on and r-maidr turned the whole figure into a picture, with no
second warning connecting the two (#227).

A plot made only of such layers still falls back, for the reason \#176
gives: `has_unsupported_layers()` is true when *every* layer is `"skip"`
as well, so "nothing unsupported" cannot quietly come to mean "nothing
at all".

Nothing here decides which geoms are readable. A
[`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
with data in it is still `"unknown"` and still costs its chart exactly
what it costs today.

#### Usage

    Ggplot2Adapter$unread_layer_type(layer, plot_object)

#### Arguments

- `layer`:

  The layer being classified

- `plot_object`:

  The ggplot2 plot object

#### Returns

`"skip"` when the layer drew no rows, `"unknown"` otherwise

------------------------------------------------------------------------

### `Ggplot2Adapter$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2Adapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
