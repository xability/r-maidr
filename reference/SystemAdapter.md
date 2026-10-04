# System Adapter Base Class

Abstract base class for adapting different plotting systems to the
unified maidr interface. Each plotting system (ggplot2, base R, lattice,
etc.) should have its own adapter implementation.

## Format

An R6 class

## Public fields

- `system_name`:

  Name of the plotting system

## Methods

### Public methods

- [`SystemAdapter$new()`](#method-SystemAdapter-initialize)

- [`SystemAdapter$can_handle()`](#method-SystemAdapter-can_handle)

- [`SystemAdapter$create_orchestrator()`](#method-SystemAdapter-create_orchestrator)

- [`SystemAdapter$clone()`](#method-SystemAdapter-clone)

------------------------------------------------------------------------

### `SystemAdapter$new()`

Initialize the adapter

#### Usage

    SystemAdapter$new(system_name)

#### Arguments

- `system_name`:

  Name of the plotting system

------------------------------------------------------------------------

### `SystemAdapter$can_handle()`

Abstract method to check if this adapter can handle a plot object

#### Usage

    SystemAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE if this adapter can handle the object, FALSE otherwise

------------------------------------------------------------------------

### `SystemAdapter$create_orchestrator()`

Abstract method to create an orchestrator for this system

#### Usage

    SystemAdapter$create_orchestrator(
      plot_object,
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `plot_object`:

  The plot object to process

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

#### Returns

Orchestrator instance specific to this system

------------------------------------------------------------------------

### `SystemAdapter$clone()`

The objects of this class are cloneable with this method.

#### Usage

    SystemAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
