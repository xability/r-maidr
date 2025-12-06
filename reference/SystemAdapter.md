# System Adapter Base Class

System Adapter Base Class

System Adapter Base Class

## Format

An R6 class

## Details

Abstract base class for adapting different plotting systems to the
unified maidr interface. Each plotting system (ggplot2, base R, lattice,
etc.) should have its own adapter implementation.

## Public fields

- `system_name`:

  Name of the plotting system

## Methods

### Public methods

- [`SystemAdapter$new()`](#method-SystemAdapter-new)

- [`SystemAdapter$can_handle()`](#method-SystemAdapter-can_handle)

- [`SystemAdapter$create_orchestrator()`](#method-SystemAdapter-create_orchestrator)

- [`SystemAdapter$clone()`](#method-SystemAdapter-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize the adapter

#### Usage

    SystemAdapter$new(system_name)

#### Arguments

- `system_name`:

  Name of the plotting system Abstract method to check if this adapter
  can handle a plot object

------------------------------------------------------------------------

### Method `can_handle()`

#### Usage

    SystemAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check

#### Returns

TRUE if this adapter can handle the object, FALSE otherwise Abstract
method to create an orchestrator for this system

------------------------------------------------------------------------

### Method `create_orchestrator()`

#### Usage

    SystemAdapter$create_orchestrator(plot_object)

#### Arguments

- `plot_object`:

  The plot object to process

#### Returns

Orchestrator instance specific to this system

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    SystemAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
