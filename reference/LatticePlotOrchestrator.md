# Plot Orchestrator for lattice

Reads a trellis object as a MAIDR figure: one subplot per panel, laid
out as lattice lays the panels out, each holding the layers its panel
function drew.

The chart is checked before it is drawn
([`lattice_static_check()`](https://r.maidr.ai/reference/lattice_static_check.md))
and audited after
([`lattice_panel_audit()`](https://r.maidr.ai/reference/lattice_panel_audit.md));
a chart that fails either is shown as an image rather than read, as an
unsupported ggplot2 or Base R chart is. A chart laid out over several
pages is read from its first.

## Methods

### Public methods

- [`LatticePlotOrchestrator$new()`](#method-LatticePlotOrchestrator-initialize)

- [`LatticePlotOrchestrator$extract_layout()`](#method-LatticePlotOrchestrator-extract_layout)

- [`LatticePlotOrchestrator$process_panels()`](#method-LatticePlotOrchestrator-process_panels)

- [`LatticePlotOrchestrator$process_layer()`](#method-LatticePlotOrchestrator-process_layer)

- [`LatticePlotOrchestrator$generate_maidr_data()`](#method-LatticePlotOrchestrator-generate_maidr_data)

- [`LatticePlotOrchestrator$get_gtable()`](#method-LatticePlotOrchestrator-get_gtable)

- [`LatticePlotOrchestrator$canvas_size()`](#method-LatticePlotOrchestrator-canvas_size)

- [`LatticePlotOrchestrator$get_layout()`](#method-LatticePlotOrchestrator-get_layout)

- [`LatticePlotOrchestrator$get_combined_data()`](#method-LatticePlotOrchestrator-get_combined_data)

- [`LatticePlotOrchestrator$get_layer_processors()`](#method-LatticePlotOrchestrator-get_layer_processors)

- [`LatticePlotOrchestrator$get_layers()`](#method-LatticePlotOrchestrator-get_layers)

- [`LatticePlotOrchestrator$unsupported_reasons()`](#method-LatticePlotOrchestrator-unsupported_reasons)

- [`LatticePlotOrchestrator$has_unsupported_layers()`](#method-LatticePlotOrchestrator-has_unsupported_layers)

- [`LatticePlotOrchestrator$should_fallback()`](#method-LatticePlotOrchestrator-should_fallback)

- [`LatticePlotOrchestrator$clone()`](#method-LatticePlotOrchestrator-clone)

------------------------------------------------------------------------

### `LatticePlotOrchestrator$new()`

Create an orchestrator for a trellis object

#### Usage

    LatticePlotOrchestrator$new(
      plot,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot`:

  The trellis object

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

------------------------------------------------------------------------

### `LatticePlotOrchestrator$extract_layout()`

Read the figure's title, subtitle and axis labels

#### Usage

    LatticePlotOrchestrator$extract_layout()

#### Returns

List with `title`, `subtitle` and `axes`

------------------------------------------------------------------------

### `LatticePlotOrchestrator$process_panels()`

Read every panel and lay the subplots out as lattice did

lattice numbers its layout rows from the bottom unless `as.table` is
set; MAIDR's grid runs top to bottom. The frontend's rows are
left-packed, so a row may end early but not start late: a cell lattice
left empty at the end of its row – a `layout` larger than the packets –
is not emitted, but one with a panel to its right – left by `skip` – is
kept as a subplot with no layers, selecting the unseen rectangle
[`lattice_draw_gaps()`](https://r.maidr.ai/reference/lattice_draw_gaps.md)
drew there, since the frontend measures every subplot to lay the figure
out
([`lattice_gap_cells()`](https://r.maidr.ai/reference/lattice_gap_cells.md)).
A row or column with no panel at all is not emitted.

Each layer is titled with its packet's strip label whenever the chart is
conditioned, even when only one panel is drawn – a conditioning variable
with one level, or the first page of a chart laid out one panel to a
page – since the strip is what says which slice of the data the panel
is. An unconditioned chart's one panel is titled with the chart's
`main`.

#### Usage

    LatticePlotOrchestrator$process_panels(packets, entries)

#### Arguments

- `packets`:

  The packet matrix, `[row, column]`, 0 for an empty cell

- `entries`:

  The panel grobs, from
  [`lattice_panel_grobs()`](https://r.maidr.ai/reference/lattice_panel_grobs.md)

#### Returns

NULL, invisibly. Sets the combined data.

------------------------------------------------------------------------

### `LatticePlotOrchestrator$process_layer()`

Read one layer of one panel

#### Usage

    LatticePlotOrchestrator$process_layer(layer, index, panel_ctx)

#### Arguments

- `layer`:

  A layer description from the adapter

- `index`:

  The layer's number across the figure

- `panel_ctx`:

  The panel the layer was drawn in

#### Returns

The layer, or NULL when its marks could not be read

------------------------------------------------------------------------

### `LatticePlotOrchestrator$generate_maidr_data()`

Assemble the MAIDR data object for the figure

#### Usage

    LatticePlotOrchestrator$generate_maidr_data()

#### Returns

List with an id, the subplots and the figure's titles

------------------------------------------------------------------------

### `LatticePlotOrchestrator$get_gtable()`

The drawn chart

#### Usage

    LatticePlotOrchestrator$get_gtable()

#### Returns

The grob the chart was drawn into, or NULL when it was not drawn

------------------------------------------------------------------------

### `LatticePlotOrchestrator$canvas_size()`

The size the chart is drawn at

#### Usage

    LatticePlotOrchestrator$canvas_size()

#### Returns

A named numeric vector, `width` and `height`, in inches

------------------------------------------------------------------------

### `LatticePlotOrchestrator$get_layout()`

The figure-level layout read by `extract_layout()`

#### Usage

    LatticePlotOrchestrator$get_layout()

#### Returns

List

------------------------------------------------------------------------

### `LatticePlotOrchestrator$get_combined_data()`

The subplot grid

#### Usage

    LatticePlotOrchestrator$get_combined_data()

#### Returns

List of rows of subplots

------------------------------------------------------------------------

### `LatticePlotOrchestrator$get_layer_processors()`

The processors created for the layers

#### Usage

    LatticePlotOrchestrator$get_layer_processors()

#### Returns

List

------------------------------------------------------------------------

### `LatticePlotOrchestrator$get_layers()`

The layers detected across the panels

#### Usage

    LatticePlotOrchestrator$get_layers()

#### Returns

List of layer descriptions

------------------------------------------------------------------------

### `LatticePlotOrchestrator$unsupported_reasons()`

Why the chart cannot be read, if it cannot

#### Usage

    LatticePlotOrchestrator$unsupported_reasons()

#### Returns

Character vector, empty when it can be read

------------------------------------------------------------------------

### `LatticePlotOrchestrator$has_unsupported_layers()`

Check if the chart holds anything that cannot be read

That is a failed check before or after drawing, a layer whose marks
could not be read, or no layer at all: a chart that announces itself as
interactive with nothing in it is worse than an image, because an image
at least says what it is.

#### Usage

    LatticePlotOrchestrator$has_unsupported_layers()

#### Returns

Logical

------------------------------------------------------------------------

### `LatticePlotOrchestrator$should_fallback()`

Determine if the chart should fall back to an image

#### Usage

    LatticePlotOrchestrator$should_fallback()

#### Returns

Logical

------------------------------------------------------------------------

### `LatticePlotOrchestrator$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticePlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
