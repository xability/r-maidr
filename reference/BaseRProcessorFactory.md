# Base R Processor Factory

Factory for creating Base R-specific processors. This factory creates
processors for Base R plot types based on recorded plot calls.

## Format

An R6 class inheriting from ProcessorFactory

## Super class

[`maidr::ProcessorFactory`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/ProcessorFactory.md)
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

- [`maidr::ProcessorFactory$supports_plot_type()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/ProcessorFactory.html#method-supports_plot_type)

------------------------------------------------------------------------

### Method `new()`

#### Usage

    BaseRProcessorFactory$new()

------------------------------------------------------------------------

### Method `create_processor()`

#### Usage

    BaseRProcessorFactory$create_processor(plot_type, layer_info)

#### Arguments

- `plot_type`:

  The type of plot (e.g., "bar", "line", "point")

- `layer_info`:

  Information about the layer (contains plot call and metadata)

#### Returns

Processor instance for the specified plot type Get list of supported
plot types

------------------------------------------------------------------------

### Method `get_supported_types()`

#### Usage

    BaseRProcessorFactory$get_supported_types()

#### Returns

Character vector of supported plot types Get the system name

------------------------------------------------------------------------

### Method `get_system_name()`

#### Usage

    BaseRProcessorFactory$get_system_name()

#### Returns

System name string Check if a specific processor class is available

------------------------------------------------------------------------

### Method `is_processor_available()`

#### Usage

    BaseRProcessorFactory$is_processor_available(processor_class_name)

#### Arguments

- `processor_class_name`:

  Name of the processor class

#### Returns

TRUE if available, FALSE otherwise Get available processor classes

------------------------------------------------------------------------

### Method `get_available_processors()`

#### Usage

    BaseRProcessorFactory$get_available_processors()

#### Returns

Character vector of available processor class names Create a processor
with error handling

------------------------------------------------------------------------

### Method `try_create_processor()`

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
