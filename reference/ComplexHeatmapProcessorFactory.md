# ComplexHeatmap Processor Factory

Each heat map of a ComplexHeatmap chart draws one matrix, read as one
`heat` layer.

## Format

An R6 class inheriting from ProcessorFactory

## Super class

[`ProcessorFactory`](https://r.maidr.ai/reference/ProcessorFactory.md)
-\> `ComplexHeatmapProcessorFactory`

## Methods

### Public methods

- [`ComplexHeatmapProcessorFactory$create_processor()`](#method-ComplexHeatmapProcessorFactory-create_processor)

- [`ComplexHeatmapProcessorFactory$get_supported_types()`](#method-ComplexHeatmapProcessorFactory-get_supported_types)

- [`ComplexHeatmapProcessorFactory$get_system_name()`](#method-ComplexHeatmapProcessorFactory-get_system_name)

- [`ComplexHeatmapProcessorFactory$clone()`](#method-ComplexHeatmapProcessorFactory-clone)

Inherited methods

- [`ProcessorFactory$supports_plot_type()`](https://r.maidr.ai/reference/ProcessorFactory.html#method-supports_plot_type)

------------------------------------------------------------------------

### `ComplexHeatmapProcessorFactory$create_processor()`

Create the processor for a layer type

#### Usage

    ComplexHeatmapProcessorFactory$create_processor(plot_type, plot_object)

#### Arguments

- `plot_type`:

  The layer type; only `"heat"` is read

- `plot_object`:

  The layer information

#### Returns

A ComplexHeatmapLayerProcessor

------------------------------------------------------------------------

### `ComplexHeatmapProcessorFactory$get_supported_types()`

The layer types this factory creates processors for

#### Usage

    ComplexHeatmapProcessorFactory$get_supported_types()

#### Returns

Character vector

------------------------------------------------------------------------

### `ComplexHeatmapProcessorFactory$get_system_name()`

Get the system name

#### Usage

    ComplexHeatmapProcessorFactory$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `ComplexHeatmapProcessorFactory$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ComplexHeatmapProcessorFactory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
