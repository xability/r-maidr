# pheatmap Plot Orchestrator

Reads the object
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
returns as a `heat` layer
([PheatmapHeatmapLayerProcessor](https://r.maidr.ai/reference/PheatmapHeatmapLayerProcessor.md))
and, for each side with a drawn dendrogram, a `tree` layer
([PheatmapTreeLayerProcessor](https://r.maidr.ai/reference/PheatmapTreeLayerProcessor.md)),
and draws its `gtable` for the SVG. Each variable of `annotation_col`
and `annotation_row` it can read exactly is a further layer of the heat
layer's subplot, after it – the column tracks, then the row tracks, each
in its data frame's column order
([PheatmapAnnotationLayerProcessor](https://r.maidr.ai/reference/PheatmapAnnotationLayerProcessor.md),
[`pheatmap_annotation_tracks()`](https://r.maidr.ai/reference/pheatmap_annotation_tracks.md)).
Experimental.

**Grid.** Each layer is a subplot placed where pheatmap draws it: the
row tree left of the matrix, the column tree above it, and nothing in
the corner above the row tree –
`[[row tree, heat], [empty, column tree]]`, as far as each side is
drawn. The grid's rows run **bottom first**. maidr.js does not measure
this grid in the SVG – it places a subplot by its layer's first
selector, which neither the heat layer's grid of selectors nor the empty
corner gives it – so it orders it as written, where the up arrow moves
to the next row; written bottom first, up moves from the matrix to the
column tree above it, and the reader starts in the bottom left subplot,
the row tree.

When the cells' values cannot be read – not drawn with
[`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md), which keeps
them, and with no legend (`legend = FALSE`) or one labelled with words,
and no numbers printed in the cells – the chart falls back to an image
rather than being read without them.

## Format

An R6 class

## Methods

### Public methods

- [`PheatmapPlotOrchestrator$new()`](#method-PheatmapPlotOrchestrator-initialize)

- [`PheatmapPlotOrchestrator$extract_layout()`](#method-PheatmapPlotOrchestrator-extract_layout)

- [`PheatmapPlotOrchestrator$generate_maidr_data()`](#method-PheatmapPlotOrchestrator-generate_maidr_data)

- [`PheatmapPlotOrchestrator$get_gtable()`](#method-PheatmapPlotOrchestrator-get_gtable)

- [`PheatmapPlotOrchestrator$canvas_size()`](#method-PheatmapPlotOrchestrator-canvas_size)

- [`PheatmapPlotOrchestrator$get_layout()`](#method-PheatmapPlotOrchestrator-get_layout)

- [`PheatmapPlotOrchestrator$get_combined_data()`](#method-PheatmapPlotOrchestrator-get_combined_data)

- [`PheatmapPlotOrchestrator$get_layer_processors()`](#method-PheatmapPlotOrchestrator-get_layer_processors)

- [`PheatmapPlotOrchestrator$get_layers()`](#method-PheatmapPlotOrchestrator-get_layers)

- [`PheatmapPlotOrchestrator$unsupported_reasons()`](#method-PheatmapPlotOrchestrator-unsupported_reasons)

- [`PheatmapPlotOrchestrator$has_unsupported_layers()`](#method-PheatmapPlotOrchestrator-has_unsupported_layers)

- [`PheatmapPlotOrchestrator$should_fallback()`](#method-PheatmapPlotOrchestrator-should_fallback)

- [`PheatmapPlotOrchestrator$clone()`](#method-PheatmapPlotOrchestrator-clone)

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$new()`

Read a pheatmap object

#### Usage

    PheatmapPlotOrchestrator$new(
      plot,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot`:

  The pheatmap object

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$extract_layout()`

Read the chart's title

#### Usage

    PheatmapPlotOrchestrator$extract_layout()

#### Returns

List with `title`

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$generate_maidr_data()`

Assemble the MAIDR data object for the figure

#### Usage

    PheatmapPlotOrchestrator$generate_maidr_data()

#### Returns

List with an id, the subplot and the title

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$get_gtable()`

The gtable drawn for the SVG, its cells renamed

#### Usage

    PheatmapPlotOrchestrator$get_gtable()

#### Returns

A gtable, or NULL

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$canvas_size()`

The size the chart is drawn at

#### Usage

    PheatmapPlotOrchestrator$canvas_size()

#### Returns

A named numeric vector, `width` and `height`, in inches

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$get_layout()`

The figure-level layout

#### Usage

    PheatmapPlotOrchestrator$get_layout()

#### Returns

List

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$get_combined_data()`

The subplot grid

#### Usage

    PheatmapPlotOrchestrator$get_combined_data()

#### Returns

List of rows of subplots

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$get_layer_processors()`

The processors created for the layers

#### Usage

    PheatmapPlotOrchestrator$get_layer_processors()

#### Returns

List

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$get_layers()`

The layers read

#### Usage

    PheatmapPlotOrchestrator$get_layers()

#### Returns

List of layer descriptions

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$unsupported_reasons()`

Why the chart cannot be read, if it cannot

#### Usage

    PheatmapPlotOrchestrator$unsupported_reasons()

#### Returns

Character vector, empty when it can be read

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$has_unsupported_layers()`

Check if the chart holds anything that cannot be read

#### Usage

    PheatmapPlotOrchestrator$has_unsupported_layers()

#### Returns

Logical

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$should_fallback()`

Determine if the chart should fall back to an image

#### Usage

    PheatmapPlotOrchestrator$should_fallback()

#### Returns

Logical

------------------------------------------------------------------------

### `PheatmapPlotOrchestrator$clone()`

The objects of this class are cloneable with this method.

#### Usage

    PheatmapPlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
