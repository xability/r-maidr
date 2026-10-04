# lattice System Adapter

Adapter for the lattice plotting system. It claims trellis objects, and
says which layers each panel of one holds.

A trellis object carries no layers of its own: what a panel holds is
what its panel function drew there. So the layers are read off the drawn
grobs – which exist, how many there are, and which group each belongs to
– while the values themselves come from the trellis object where it
holds them exactly (`panel.args`) and from the grobs where lattice
computed them while drawing (a density curve, a loess fit).

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`SystemAdapter`](https://r.maidr.ai/reference/SystemAdapter.md) -\>
`LatticeAdapter`

## Methods

### Public methods

- [`LatticeAdapter$new()`](#method-LatticeAdapter-initialize)

- [`LatticeAdapter$can_handle()`](#method-LatticeAdapter-can_handle)

- [`LatticeAdapter$detect_layer_type()`](#method-LatticeAdapter-detect_layer_type)

- [`LatticeAdapter$detect_panel_layers()`](#method-LatticeAdapter-detect_panel_layers)

- [`LatticeAdapter$bar_type()`](#method-LatticeAdapter-bar_type)

- [`LatticeAdapter$draws_steps()`](#method-LatticeAdapter-draws_steps)

- [`LatticeAdapter$is_one_dot_per_level()`](#method-LatticeAdapter-is_one_dot_per_level)

- [`LatticeAdapter$create_orchestrator()`](#method-LatticeAdapter-create_orchestrator)

- [`LatticeAdapter$get_system_name()`](#method-LatticeAdapter-get_system_name)

- [`LatticeAdapter$clone()`](#method-LatticeAdapter-clone)

------------------------------------------------------------------------

### `LatticeAdapter$new()`

Initialize the lattice adapter

#### Usage

    LatticeAdapter$new()

------------------------------------------------------------------------

### `LatticeAdapter$can_handle()`

Check if this adapter can handle a plot object

A bare latticeExtra
[`layer()`](https://ggplot2.tidyverse.org/reference/layer.html) is also
classed `"trellis"`, but it is an overlay waiting for a chart rather
than a chart.

#### Usage

    LatticeAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE for a trellis object, FALSE otherwise

------------------------------------------------------------------------

### `LatticeAdapter$detect_layer_type()`

Classify one grob a panel function drew

#### Usage

    LatticeAdapter$detect_layer_type(layer, plot_object)

#### Arguments

- `layer`:

  A grob entry: a list with the grob's `what` part

- `plot_object`:

  The trellis object

#### Returns

The grob's role (see `LATTICE_PANEL_ROLES`), `"decoration"`,
`"observations"`, or `"unknown"`

------------------------------------------------------------------------

### `LatticeAdapter$detect_panel_layers()`

Group one panel's grobs into the layers it is read as

Each layer is a list with the maidr `type` it is emitted as, the `role`
of its grobs and the `grobs` themselves. A mark-per-observation type –
points, dots, spikes – is one layer per group, named after it; a curve
type is one layer per kind of curve, holding a series per group; bars,
bins, boxes and cells are one layer for the panel.

#### Usage

    LatticeAdapter$detect_panel_layers(entries, plot_object, args)

#### Arguments

- `entries`:

  Grob entries drawn in the panel, in drawing order: lists with `name`,
  `what`, `group` and `role`

- `plot_object`:

  The trellis object

- `args`:

  The panel's arguments, as its panel function received them

#### Returns

A list of layer descriptions, in drawing order

------------------------------------------------------------------------

### `LatticeAdapter$bar_type()`

The bar layer type a barchart panel is read as

#### Usage

    LatticeAdapter$bar_type(args)

#### Arguments

- `args`:

  The panel's arguments

#### Returns

`"bar"`, `"dodged_bar"` or `"stacked_bar"`

------------------------------------------------------------------------

### `LatticeAdapter$draws_steps()`

Whether an xyplot draws its lines as steps

`type = "s"` and `"S"` draw the one `xyplot.lines` grob `"l"` does, as a
staircase. With `distribute.type = TRUE` each group has a type of its
own, the types recycled over the groups
([`lattice_group_type()`](https://r.maidr.ai/reference/lattice_group_type.md)).

#### Usage

    LatticeAdapter$draws_steps(args, group)

#### Arguments

- `args`:

  The panel's arguments

- `group`:

  The group the lines belong to, or NA

#### Returns

TRUE for steps

------------------------------------------------------------------------

### `LatticeAdapter$is_one_dot_per_level()`

Whether a dotplot draws at most one dot per level

A Cleveland dot plot – one value per category, marked with a dot on a
guide line – is read as a `dot` layer, a bar chart's reading with a
different mark, as Base R's
[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) is. A
dotplot with several values on a level is a strip of points instead, and
read as points named by their level.

#### Usage

    LatticeAdapter$is_one_dot_per_level(args, group)

#### Arguments

- `args`:

  The panel's arguments

- `group`:

  The group the dots belong to, or NA

#### Returns

TRUE when no level holds two dots

------------------------------------------------------------------------

### `LatticeAdapter$create_orchestrator()`

Create an orchestrator for a trellis object

#### Usage

    LatticeAdapter$create_orchestrator(
      plot_object,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot_object`:

  The trellis object

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

#### Returns

LatticePlotOrchestrator instance

------------------------------------------------------------------------

### `LatticeAdapter$get_system_name()`

Get the system name

#### Usage

    LatticeAdapter$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `LatticeAdapter$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
