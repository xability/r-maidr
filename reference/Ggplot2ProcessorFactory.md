# ggplot2 Processor Factory

Factory for creating ggplot2-specific processors. This factory uses the
existing ggplot2 layer processors and wraps them in the new unified
interface.

## Format

An R6 class inheriting from ProcessorFactory

## Super class

[`ProcessorFactory`](https://r.maidr.ai/reference/ProcessorFactory.md)
-\> `Ggplot2ProcessorFactory`

## Methods

### Public methods

- [`Ggplot2ProcessorFactory$new()`](#method-Ggplot2ProcessorFactory-initialize)

- [`Ggplot2ProcessorFactory$create_processor()`](#method-Ggplot2ProcessorFactory-create_processor)

- [`Ggplot2ProcessorFactory$get_supported_types()`](#method-Ggplot2ProcessorFactory-get_supported_types)

- [`Ggplot2ProcessorFactory$get_system_name()`](#method-Ggplot2ProcessorFactory-get_system_name)

- [`Ggplot2ProcessorFactory$is_processor_available()`](#method-Ggplot2ProcessorFactory-is_processor_available)

- [`Ggplot2ProcessorFactory$get_available_processors()`](#method-Ggplot2ProcessorFactory-get_available_processors)

- [`Ggplot2ProcessorFactory$try_create_processor()`](#method-Ggplot2ProcessorFactory-try_create_processor)

- [`Ggplot2ProcessorFactory$clone()`](#method-Ggplot2ProcessorFactory-clone)

Inherited methods

- [`ProcessorFactory$supports_plot_type()`](https://r.maidr.ai/reference/ProcessorFactory.html#method-supports_plot_type)

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$new()`

Initialize the ggplot2 processor factory

#### Usage

    Ggplot2ProcessorFactory$new()

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$create_processor()`

Create a processor for a specific plot type

#### Usage

    Ggplot2ProcessorFactory$create_processor(plot_type, layer_info)

#### Arguments

- `plot_type`:

  The type of plot (e.g., "bar", "line", "point")

- `layer_info`:

  Information about the layer (contains plot object and metadata)

#### Returns

Processor instance for the specified plot type

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$get_supported_types()`

Get list of supported plot types

#### Usage

    Ggplot2ProcessorFactory$get_supported_types()

#### Returns

Character vector of supported plot types

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$get_system_name()`

Get the system name

#### Usage

    Ggplot2ProcessorFactory$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$is_processor_available()`

Check if a specific processor class is available

#### Usage

    Ggplot2ProcessorFactory$is_processor_available(processor_class_name)

#### Arguments

- `processor_class_name`:

  Name of the processor class

#### Returns

TRUE if available, FALSE otherwise

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$get_available_processors()`

Get available processor classes

#### Usage

    Ggplot2ProcessorFactory$get_available_processors()

#### Returns

Character vector of available processor class names

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$try_create_processor()`

Create a processor with error handling

#### Usage

    Ggplot2ProcessorFactory$try_create_processor(plot_type, plot_object)

#### Arguments

- `plot_type`:

  The type of plot

- `plot_object`:

  The plot object

#### Returns

Processor instance or NULL if creation fails

------------------------------------------------------------------------

### `Ggplot2ProcessorFactory$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2ProcessorFactory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
