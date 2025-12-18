# ggplot2 System Adapter

Adapter for the ggplot2 plotting system. This adapter wraps the existing
ggplot2 functionality to work with the new extensible architecture.

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`maidr::SystemAdapter`](https://r.maidr.ai/reference/SystemAdapter.md)
-\> `Ggplot2Adapter`

## Methods

### Public methods

- [`Ggplot2Adapter$new()`](#method-Ggplot2Adapter-new)

- [`Ggplot2Adapter$can_handle()`](#method-Ggplot2Adapter-can_handle)

- [`Ggplot2Adapter$detect_layer_type()`](#method-Ggplot2Adapter-detect_layer_type)

- [`Ggplot2Adapter$create_orchestrator()`](#method-Ggplot2Adapter-create_orchestrator)

- [`Ggplot2Adapter$get_system_name()`](#method-Ggplot2Adapter-get_system_name)

- [`Ggplot2Adapter$get_adapter()`](#method-Ggplot2Adapter-get_adapter)

- [`Ggplot2Adapter$has_facets()`](#method-Ggplot2Adapter-has_facets)

- [`Ggplot2Adapter$is_patchwork()`](#method-Ggplot2Adapter-is_patchwork)

- [`Ggplot2Adapter$clone()`](#method-Ggplot2Adapter-clone)

------------------------------------------------------------------------

### Method `new()`

#### Usage

    Ggplot2Adapter$new()

------------------------------------------------------------------------

### Method `can_handle()`

#### Usage

    Ggplot2Adapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE if this adapter can handle the object, FALSE otherwise Detect the
type of a single layer

------------------------------------------------------------------------

### Method `detect_layer_type()`

#### Usage

    Ggplot2Adapter$detect_layer_type(layer, plot_object)

#### Arguments

- `layer`:

  The ggplot2 layer object to analyze

- `plot_object`:

  The parent plot object (for context)

#### Returns

String indicating the layer type (e.g., "bar", "line", "point") Create
an orchestrator for this system (ggplot2)

------------------------------------------------------------------------

### Method `create_orchestrator()`

#### Usage

    Ggplot2Adapter$create_orchestrator(plot_object)

#### Arguments

- `plot_object`:

  The ggplot2 plot object to process

#### Returns

PlotOrchestrator instance Get the system name

------------------------------------------------------------------------

### Method `get_system_name()`

#### Usage

    Ggplot2Adapter$get_system_name()

#### Returns

System name string Get a reference to this adapter (for use by
orchestrator)

------------------------------------------------------------------------

### Method `get_adapter()`

#### Usage

    Ggplot2Adapter$get_adapter()

#### Returns

Self reference Check if plot has facets

------------------------------------------------------------------------

### Method `has_facets()`

#### Usage

    Ggplot2Adapter$has_facets(plot_object)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

#### Returns

TRUE if plot has facets, FALSE otherwise Check if plot is a patchwork
plot

------------------------------------------------------------------------

### Method `is_patchwork()`

#### Usage

    Ggplot2Adapter$is_patchwork(plot_object)

#### Arguments

- `plot_object`:

  The ggplot2 plot object

#### Returns

TRUE if plot is patchwork, FALSE otherwise

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2Adapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
