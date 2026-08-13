# Base R Patch Architecture

Modular system for patching Base R plotting functions with chain of
responsibility pattern

## Methods

### Public methods

- [`BaseRPatcher$can_patch()`](#method-BaseRPatcher-can_patch)

- [`BaseRPatcher$apply_patch()`](#method-BaseRPatcher-apply_patch)

- [`BaseRPatcher$get_name()`](#method-BaseRPatcher-get_name)

- [`BaseRPatcher$clone()`](#method-BaseRPatcher-clone)

------------------------------------------------------------------------

### `BaseRPatcher$can_patch()`

#### Usage

    BaseRPatcher$can_patch(function_name, args)

------------------------------------------------------------------------

### `BaseRPatcher$apply_patch()`

#### Usage

    BaseRPatcher$apply_patch(function_name, args)

------------------------------------------------------------------------

### `BaseRPatcher$get_name()`

#### Usage

    BaseRPatcher$get_name()

------------------------------------------------------------------------

### `BaseRPatcher$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPatcher$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
