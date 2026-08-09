# Plot System Registry

Central registry for managing different plotting systems and their
adapters. This registry allows dynamic registration and discovery of
plotting systems and their associated adapters and processor factories.

## Format

An R6 class

## Methods

### Public methods

- [`PlotSystemRegistry$register_system()`](#method-PlotSystemRegistry-register_system)

- [`PlotSystemRegistry$detect_system()`](#method-PlotSystemRegistry-detect_system)

- [`PlotSystemRegistry$get_adapter()`](#method-PlotSystemRegistry-get_adapter)

- [`PlotSystemRegistry$get_processor_factory()`](#method-PlotSystemRegistry-get_processor_factory)

- [`PlotSystemRegistry$get_adapter_for_plot()`](#method-PlotSystemRegistry-get_adapter_for_plot)

- [`PlotSystemRegistry$get_processor_factory_for_plot()`](#method-PlotSystemRegistry-get_processor_factory_for_plot)

- [`PlotSystemRegistry$list_systems()`](#method-PlotSystemRegistry-list_systems)

- [`PlotSystemRegistry$is_system_registered()`](#method-PlotSystemRegistry-is_system_registered)

- [`PlotSystemRegistry$unregister_system()`](#method-PlotSystemRegistry-unregister_system)

- [`PlotSystemRegistry$clone()`](#method-PlotSystemRegistry-clone)

------------------------------------------------------------------------

### Method `register_system()`

Registered plotting systems

System adapters

Processor factories

Register a new plotting system

#### Usage

    PlotSystemRegistry$register_system(system_name, adapter, processor_factory)

#### Arguments

- `system_name`:

  Name of the plotting system (e.g., "ggplot2", "base_r")

- `adapter`:

  Adapter instance for this system

- `processor_factory`:

  Processor factory instance for this system

------------------------------------------------------------------------

### Method `detect_system()`

Detect which system can handle a plot object

#### Usage

    PlotSystemRegistry$detect_system(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

System name if found, NULL otherwise

------------------------------------------------------------------------

### Method `get_adapter()`

Get the adapter for a specific system

#### Usage

    PlotSystemRegistry$get_adapter(system_name)

#### Arguments

- `system_name`:

  Name of the system

#### Returns

Adapter instance

------------------------------------------------------------------------

### Method `get_processor_factory()`

Get the processor factory for a specific system

#### Usage

    PlotSystemRegistry$get_processor_factory(system_name)

#### Arguments

- `system_name`:

  Name of the system

#### Returns

Processor factory instance

------------------------------------------------------------------------

### Method `get_adapter_for_plot()`

Get the adapter for a plot object (auto-detect system)

#### Usage

    PlotSystemRegistry$get_adapter_for_plot(plot_object)

#### Arguments

- `plot_object`:

  The plot object

#### Returns

Adapter instance

------------------------------------------------------------------------

### Method `get_processor_factory_for_plot()`

Get the processor factory for a plot object (auto-detect system)

#### Usage

    PlotSystemRegistry$get_processor_factory_for_plot(plot_object)

#### Arguments

- `plot_object`:

  The plot object

#### Returns

Processor factory instance

------------------------------------------------------------------------

### Method `list_systems()`

List all registered systems

#### Usage

    PlotSystemRegistry$list_systems()

#### Returns

Character vector of registered system names

------------------------------------------------------------------------

### Method `is_system_registered()`

Check if a system is registered

#### Usage

    PlotSystemRegistry$is_system_registered(system_name)

#### Arguments

- `system_name`:

  Name of the system

#### Returns

TRUE if registered, FALSE otherwise

------------------------------------------------------------------------

### Method `unregister_system()`

Unregister a system

#### Usage

    PlotSystemRegistry$unregister_system(system_name)

#### Arguments

- `system_name`:

  Name of the system to unregister

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    PlotSystemRegistry$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
