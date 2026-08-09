# Base R Processor Factory

Factory for creating Base R-specific processors. This factory creates
processors for Base R plot types based on recorded plot calls.

## Format

An R6 class inheriting from ProcessorFactory

## Super class

[`maidr::ProcessorFactory`](https://r.maidr.ai/reference/ProcessorFactory.md)
-\> `BaseRProcessorFactory`

## Methods

### Public methods

- [`BaseRProcessorFactory$new()`](#method-BaseRProcessorFactory-new)

- [`BaseRProcessorFactory$create_processor()`](#method-BaseRProcessorFactory-create_processor)

- [`BaseRProcessorFactory$get_supported_types()`](#method-BaseRProcessorFactory-get_supported_types)

- [`BaseRProcessorFactory$get_system_name()`](#method-BaseRProcessorFactory-get_system_name)

- [`BaseRProcessorFactory$is_processor_available()`](#method-BaseRProcessorFactory-is_processor_available)

- [`BaseRProcessorFactory$get_available_processors()`](#method-BaseRProcessorFactory-get_available_processors)

- [`BaseRProcessorFactory$try_create_processor()`](#method-BaseRProcessorFactory-try_create_processor)

- [`BaseRProcessorFactory$clone()`](#method-BaseRProcessorFactory-clone)

Inherited methods

- [`maidr::ProcessorFactory$supports_plot_type()`](https://r.maidr.ai/reference/ProcessorFactory.html#method-supports_plot_type)

------------------------------------------------------------------------

### Method `new()`

Initialize the Base R processor factory

#### Usage

    BaseRProcessorFactory$new()

------------------------------------------------------------------------

### Method `create_processor()`

Create a processor for a specific plot type

#### Usage

    BaseRProcessorFactory$create_processor(plot_type, layer_info)

#### Arguments

- `plot_type`:

  The type of plot (e.g., "bar", "line", "point")

- `layer_info`:

  Information about the layer (contains plot call and metadata)

#### Returns

Processor instance for the specified plot type

------------------------------------------------------------------------

### Method `get_supported_types()`

Get list of supported plot types

#### Usage

    BaseRProcessorFactory$get_supported_types()

#### Returns

Character vector of supported plot types

------------------------------------------------------------------------

### Method `get_system_name()`

Get the system name

#### Usage

    BaseRProcessorFactory$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### Method `is_processor_available()`

Check if a specific processor class is available

#### Usage

    BaseRProcessorFactory$is_processor_available(processor_class_name)

#### Arguments

- `processor_class_name`:

  Name of the processor class

#### Returns

TRUE if available, FALSE otherwise

------------------------------------------------------------------------

### Method `get_available_processors()`

Get available processor classes

#### Usage

    BaseRProcessorFactory$get_available_processors()

#### Returns

Character vector of available processor class names

------------------------------------------------------------------------

### Method `try_create_processor()`

Create a processor with error handling

#### Usage

    BaseRProcessorFactory$try_create_processor(plot_type, layer_info)

#### Arguments

- `plot_type`:

  The type of plot

- `layer_info`:

  The layer information

#### Returns

Processor instance or NULL if creation fails

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRProcessorFactory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
