# ComplexHeatmap Plot Orchestrator

Reads a 'ComplexHeatmap' heat map – a `Heatmap`, or a `HeatmapList`
holding exactly one – as one subplot holding one `heat` layer
([ComplexHeatmapLayerProcessor](https://r.maidr.ai/reference/ComplexHeatmapLayerProcessor.md)).
Experimental.

The object is drawn once, with
[`ComplexHeatmap::draw()`](https://rdrr.io/pkg/ComplexHeatmap/man/draw-dispatch.html),
and the drawing is grabbed as a grid tree
([`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md)).
The SVG is that tree, and the layer is read from the `HeatmapList` that
same draw returned, so the order of the rows and columns read is the
order drawn even where drawing decides it afresh – `row_km`'s k-means,
say, which an undrawn `Heatmap` runs again on every draw. Pass what
`draw()` returned to read the very chart that was shown.

Only the matrix is read. The dendrograms set the order the cells are
read in but are not read themselves, and neither are annotations or
legends. A list of more than one heat map, or a matrix that is not
numeric (a discrete heat map of categories), falls back to an image.

## Format

An R6 class

## Methods

### Public methods

- [`ComplexHeatmapPlotOrchestrator$new()`](#method-ComplexHeatmapPlotOrchestrator-initialize)

- [`ComplexHeatmapPlotOrchestrator$extract_layout()`](#method-ComplexHeatmapPlotOrchestrator-extract_layout)

- [`ComplexHeatmapPlotOrchestrator$generate_maidr_data()`](#method-ComplexHeatmapPlotOrchestrator-generate_maidr_data)

- [`ComplexHeatmapPlotOrchestrator$get_gtable()`](#method-ComplexHeatmapPlotOrchestrator-get_gtable)

- [`ComplexHeatmapPlotOrchestrator$canvas_size()`](#method-ComplexHeatmapPlotOrchestrator-canvas_size)

- [`ComplexHeatmapPlotOrchestrator$get_layout()`](#method-ComplexHeatmapPlotOrchestrator-get_layout)

- [`ComplexHeatmapPlotOrchestrator$get_combined_data()`](#method-ComplexHeatmapPlotOrchestrator-get_combined_data)

- [`ComplexHeatmapPlotOrchestrator$get_layer_processors()`](#method-ComplexHeatmapPlotOrchestrator-get_layer_processors)

- [`ComplexHeatmapPlotOrchestrator$get_layers()`](#method-ComplexHeatmapPlotOrchestrator-get_layers)

- [`ComplexHeatmapPlotOrchestrator$unsupported_reasons()`](#method-ComplexHeatmapPlotOrchestrator-unsupported_reasons)

- [`ComplexHeatmapPlotOrchestrator$has_unsupported_layers()`](#method-ComplexHeatmapPlotOrchestrator-has_unsupported_layers)

- [`ComplexHeatmapPlotOrchestrator$should_fallback()`](#method-ComplexHeatmapPlotOrchestrator-should_fallback)

- [`ComplexHeatmapPlotOrchestrator$clone()`](#method-ComplexHeatmapPlotOrchestrator-clone)

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$new()`

Read a ComplexHeatmap object

#### Usage

    ComplexHeatmapPlotOrchestrator$new(
      plot,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot`:

  The `Heatmap` or `HeatmapList`

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$extract_layout()`

Read the chart's title and its rows' title

The title is the column title `draw()` was given for the whole list,
else the heat map's own column title when it is one string; the rows'
title likewise from the row titles. A title per slice of a split names
no axis and is not read.

#### Usage

    ComplexHeatmapPlotOrchestrator$extract_layout()

#### Returns

List with `title` and `row_title`

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$generate_maidr_data()`

Assemble the MAIDR data object for the figure

#### Usage

    ComplexHeatmapPlotOrchestrator$generate_maidr_data()

#### Returns

List with an id, the subplot and the title

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$get_gtable()`

The grid tree drawn for the SVG, its cells renamed

#### Usage

    ComplexHeatmapPlotOrchestrator$get_gtable()

#### Returns

A gTree, or NULL when the chart could not be drawn

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$canvas_size()`

The size the chart is drawn at

#### Usage

    ComplexHeatmapPlotOrchestrator$canvas_size()

#### Returns

A named numeric vector, `width` and `height`, in inches

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$get_layout()`

The figure-level layout

#### Usage

    ComplexHeatmapPlotOrchestrator$get_layout()

#### Returns

List

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$get_combined_data()`

The subplot grid

#### Usage

    ComplexHeatmapPlotOrchestrator$get_combined_data()

#### Returns

List of rows of subplots

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$get_layer_processors()`

The processors created for the layers

#### Usage

    ComplexHeatmapPlotOrchestrator$get_layer_processors()

#### Returns

List

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$get_layers()`

The layers read

#### Usage

    ComplexHeatmapPlotOrchestrator$get_layers()

#### Returns

List of layer descriptions

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$unsupported_reasons()`

Why the chart cannot be read, if it cannot

#### Usage

    ComplexHeatmapPlotOrchestrator$unsupported_reasons()

#### Returns

Character vector, empty when it can be read

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$has_unsupported_layers()`

Check if the chart holds anything that cannot be read

#### Usage

    ComplexHeatmapPlotOrchestrator$has_unsupported_layers()

#### Returns

Logical

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$should_fallback()`

Determine if the chart should fall back to an image

#### Usage

    ComplexHeatmapPlotOrchestrator$should_fallback()

#### Returns

Logical

------------------------------------------------------------------------

### `ComplexHeatmapPlotOrchestrator$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ComplexHeatmapPlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
