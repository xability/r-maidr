# pheatmap Processor Factory

A pheatmap draws one matrix, read as one `heat` layer.

## Format

An R6 class inheriting from ProcessorFactory

## Super class

[`ProcessorFactory`](https://r.maidr.ai/reference/ProcessorFactory.md)
-\> `PheatmapProcessorFactory`

## Methods

### Public methods

- [`PheatmapProcessorFactory$create_processor()`](#method-PheatmapProcessorFactory-create_processor)

- [`PheatmapProcessorFactory$get_supported_types()`](#method-PheatmapProcessorFactory-get_supported_types)

- [`PheatmapProcessorFactory$get_system_name()`](#method-PheatmapProcessorFactory-get_system_name)

- [`PheatmapProcessorFactory$clone()`](#method-PheatmapProcessorFactory-clone)

Inherited methods

- [`ProcessorFactory$supports_plot_type()`](https://r.maidr.ai/reference/ProcessorFactory.html#method-supports_plot_type)

------------------------------------------------------------------------

### `PheatmapProcessorFactory$create_processor()`

Create the processor for a layer type

#### Usage

    PheatmapProcessorFactory$create_processor(plot_type, plot_object)

#### Arguments

- `plot_type`:

  The layer type; only `"heat"` is read

- `plot_object`:

  The layer information

#### Returns

A PheatmapHeatmapLayerProcessor

------------------------------------------------------------------------

### `PheatmapProcessorFactory$get_supported_types()`

The layer types this factory creates processors for

#### Usage

    PheatmapProcessorFactory$get_supported_types()

#### Returns

Character vector

------------------------------------------------------------------------

### `PheatmapProcessorFactory$get_system_name()`

Get the system name

#### Usage

    PheatmapProcessorFactory$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `PheatmapProcessorFactory$clone()`

The objects of this class are cloneable with this method.

#### Usage

    PheatmapProcessorFactory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
