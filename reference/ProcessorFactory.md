# Processor Factory Base Class

Abstract base class for creating processors specific to different
plotting systems. Each plotting system should have its own factory
implementation that creates the appropriate processors for different
plot types.

## Format

An R6 class

## Methods

### Public methods

- [`ProcessorFactory$create_processor()`](#method-ProcessorFactory-create_processor)

- [`ProcessorFactory$get_supported_types()`](#method-ProcessorFactory-get_supported_types)

- [`ProcessorFactory$supports_plot_type()`](#method-ProcessorFactory-supports_plot_type)

- [`ProcessorFactory$get_system_name()`](#method-ProcessorFactory-get_system_name)

- [`ProcessorFactory$clone()`](#method-ProcessorFactory-clone)

------------------------------------------------------------------------

### `ProcessorFactory$create_processor()`

Abstract method to create a processor for a specific plot type

#### Usage

    ProcessorFactory$create_processor(plot_type, plot_object)

#### Arguments

- `plot_type`:

  The type of plot (e.g., "bar", "line", "point")

- `plot_object`:

  The plot object to process

#### Returns

Processor instance for the specified plot type

------------------------------------------------------------------------

### `ProcessorFactory$get_supported_types()`

Abstract method to get list of supported plot types

#### Usage

    ProcessorFactory$get_supported_types()

#### Returns

Character vector of supported plot types

------------------------------------------------------------------------

### `ProcessorFactory$supports_plot_type()`

Check if a plot type is supported by this factory

#### Usage

    ProcessorFactory$supports_plot_type(plot_type)

#### Arguments

- `plot_type`:

  The plot type to check

#### Returns

TRUE if supported, FALSE otherwise

------------------------------------------------------------------------

### `ProcessorFactory$get_system_name()`

Get system name (should be overridden by subclasses)

#### Usage

    ProcessorFactory$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `ProcessorFactory$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ProcessorFactory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
