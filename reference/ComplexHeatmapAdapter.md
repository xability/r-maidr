# ComplexHeatmap System Adapter

Adapter for heat maps drawn by the Bioconductor package
'ComplexHeatmap'. It claims a `Heatmap` – what
[`ComplexHeatmap::Heatmap()`](https://rdrr.io/pkg/ComplexHeatmap/man/Heatmap.html)
returns – and a `HeatmapList`, what `draw()` returns or `+` builds, and
reads it with
[ComplexHeatmapPlotOrchestrator](https://r.maidr.ai/reference/ComplexHeatmapPlotOrchestrator.md).
'ComplexHeatmap' is only suggested; it is loaded when such an object is
read, which it must have been for the object to exist.

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`SystemAdapter`](https://r.maidr.ai/reference/SystemAdapter.md) -\>
`ComplexHeatmapAdapter`

## Methods

### Public methods

- [`ComplexHeatmapAdapter$new()`](#method-ComplexHeatmapAdapter-initialize)

- [`ComplexHeatmapAdapter$can_handle()`](#method-ComplexHeatmapAdapter-can_handle)

- [`ComplexHeatmapAdapter$create_orchestrator()`](#method-ComplexHeatmapAdapter-create_orchestrator)

- [`ComplexHeatmapAdapter$get_system_name()`](#method-ComplexHeatmapAdapter-get_system_name)

- [`ComplexHeatmapAdapter$clone()`](#method-ComplexHeatmapAdapter-clone)

------------------------------------------------------------------------

### `ComplexHeatmapAdapter$new()`

Initialize the ComplexHeatmap adapter

#### Usage

    ComplexHeatmapAdapter$new()

------------------------------------------------------------------------

### `ComplexHeatmapAdapter$can_handle()`

Check if this adapter can handle a plot object

#### Usage

    ComplexHeatmapAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE for a ComplexHeatmap `Heatmap` or `HeatmapList`

------------------------------------------------------------------------

### `ComplexHeatmapAdapter$create_orchestrator()`

Create an orchestrator for a ComplexHeatmap object

#### Usage

    ComplexHeatmapAdapter$create_orchestrator(
      plot_object,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot_object`:

  The `Heatmap` or `HeatmapList`

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

#### Returns

ComplexHeatmapPlotOrchestrator instance

------------------------------------------------------------------------

### `ComplexHeatmapAdapter$get_system_name()`

Get the system name

#### Usage

    ComplexHeatmapAdapter$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `ComplexHeatmapAdapter$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ComplexHeatmapAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
