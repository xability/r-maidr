# pheatmap System Adapter

Adapter for clustered heat maps drawn by the 'pheatmap' package. It
claims the object
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
returns – a list of class `"pheatmap"` holding the row and column trees
and the drawn `gtable` – and reads it with
[PheatmapPlotOrchestrator](https://r.maidr.ai/reference/PheatmapPlotOrchestrator.md).
'pheatmap' itself is only suggested: nothing here calls it, the object
carries everything that is read.

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`SystemAdapter`](https://r.maidr.ai/reference/SystemAdapter.md) -\>
`PheatmapAdapter`

## Methods

### Public methods

- [`PheatmapAdapter$new()`](#method-PheatmapAdapter-initialize)

- [`PheatmapAdapter$can_handle()`](#method-PheatmapAdapter-can_handle)

- [`PheatmapAdapter$create_orchestrator()`](#method-PheatmapAdapter-create_orchestrator)

- [`PheatmapAdapter$get_system_name()`](#method-PheatmapAdapter-get_system_name)

- [`PheatmapAdapter$clone()`](#method-PheatmapAdapter-clone)

------------------------------------------------------------------------

### `PheatmapAdapter$new()`

Initialize the pheatmap adapter

#### Usage

    PheatmapAdapter$new()

------------------------------------------------------------------------

### `PheatmapAdapter$can_handle()`

Check if this adapter can handle a plot object

#### Usage

    PheatmapAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE for the object
[`pheatmap::pheatmap()`](https://rdrr.io/pkg/pheatmap/man/pheatmap.html)
returns

------------------------------------------------------------------------

### `PheatmapAdapter$create_orchestrator()`

Create an orchestrator for a pheatmap object

#### Usage

    PheatmapAdapter$create_orchestrator(
      plot_object,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot_object`:

  The pheatmap object

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

#### Returns

PheatmapPlotOrchestrator instance

------------------------------------------------------------------------

### `PheatmapAdapter$get_system_name()`

Get the system name

#### Usage

    PheatmapAdapter$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `PheatmapAdapter$clone()`

The objects of this class are cloneable with this method.

#### Usage

    PheatmapAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
