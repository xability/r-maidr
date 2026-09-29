# lattice Processor Factory

Factory for the processors that read the layers of a lattice panel. The
layer types are the ones the lattice adapter detects from the grobs a
panel function draws (`LatticeAdapter$detect_panel_layers()`).

## Format

An R6 class inheriting from ProcessorFactory

## Super class

[`ProcessorFactory`](https://r.maidr.ai/reference/ProcessorFactory.md)
-\> `LatticeProcessorFactory`

## Methods

### Public methods

- [`LatticeProcessorFactory$new()`](#method-LatticeProcessorFactory-initialize)

- [`LatticeProcessorFactory$create_processor()`](#method-LatticeProcessorFactory-create_processor)

- [`LatticeProcessorFactory$get_supported_types()`](#method-LatticeProcessorFactory-get_supported_types)

- [`LatticeProcessorFactory$get_system_name()`](#method-LatticeProcessorFactory-get_system_name)

- [`LatticeProcessorFactory$is_processor_available()`](#method-LatticeProcessorFactory-is_processor_available)

- [`LatticeProcessorFactory$get_available_processors()`](#method-LatticeProcessorFactory-get_available_processors)

- [`LatticeProcessorFactory$clone()`](#method-LatticeProcessorFactory-clone)

Inherited methods

- [`ProcessorFactory$supports_plot_type()`](https://r.maidr.ai/reference/ProcessorFactory.html#method-supports_plot_type)

------------------------------------------------------------------------

### `LatticeProcessorFactory$new()`

Initialize the lattice processor factory

#### Usage

    LatticeProcessorFactory$new()

------------------------------------------------------------------------

### `LatticeProcessorFactory$create_processor()`

Create a processor for a specific layer type

#### Usage

    LatticeProcessorFactory$create_processor(plot_type, layer_info)

#### Arguments

- `plot_type`:

  The layer type (e.g., "bar", "line", "point")

- `layer_info`:

  Information about the layer: its type, role and the grobs it is read
  from

#### Returns

Processor instance for the specified layer type

------------------------------------------------------------------------

### `LatticeProcessorFactory$get_supported_types()`

Get list of supported layer types

#### Usage

    LatticeProcessorFactory$get_supported_types()

#### Returns

Character vector of supported layer types

------------------------------------------------------------------------

### `LatticeProcessorFactory$get_system_name()`

Get the system name

#### Usage

    LatticeProcessorFactory$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `LatticeProcessorFactory$is_processor_available()`

Check if a specific processor class is available

#### Usage

    LatticeProcessorFactory$is_processor_available(processor_class_name)

#### Arguments

- `processor_class_name`:

  Name of the processor class

#### Returns

TRUE if available, FALSE otherwise

------------------------------------------------------------------------

### `LatticeProcessorFactory$get_available_processors()`

Get available processor classes

Enumerated from `create_processor()` rather than listed here, so the
answer cannot drift away from what the factory actually dispatches to
(#200).

#### Usage

    LatticeProcessorFactory$get_available_processors()

#### Returns

Character vector of available processor class names

------------------------------------------------------------------------

### `LatticeProcessorFactory$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LatticeProcessorFactory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
