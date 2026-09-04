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

Abstract: whether this patcher applies to the call

#### Usage

    BaseRPatcher$can_patch(function_name, args)

#### Arguments

- `function_name`:

  Name of the plotting function

- `args`:

  Recorded argument list

#### Returns

Logical

------------------------------------------------------------------------

### `BaseRPatcher$apply_patch()`

Abstract: the argument list with this patcher's change applied

#### Usage

    BaseRPatcher$apply_patch(function_name, args)

#### Arguments

- `function_name`:

  Name of the plotting function

- `args`:

  Recorded argument list

#### Returns

Argument list

------------------------------------------------------------------------

### `BaseRPatcher$get_name()`

Get the patcher name for debugging

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
