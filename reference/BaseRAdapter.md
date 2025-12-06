# Base R System Adapter

Adapter for the Base R plotting system. This adapter uses function
patching to intercept Base R plotting calls and detect plot types.

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`maidr::SystemAdapter`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/SystemAdapter.md)
-\> `BaseRAdapter`

## Methods

### Public methods

- [`BaseRAdapter$new()`](#method-BaseRAdapter-new)

- [`BaseRAdapter$can_handle()`](#method-BaseRAdapter-can_handle)

- [`BaseRAdapter$detect_layer_type()`](#method-BaseRAdapter-detect_layer_type)

- [`BaseRAdapter$is_dodged_barplot()`](#method-BaseRAdapter-is_dodged_barplot)

- [`BaseRAdapter$is_stacked_barplot()`](#method-BaseRAdapter-is_stacked_barplot)

- [`BaseRAdapter$create_orchestrator()`](#method-BaseRAdapter-create_orchestrator)

- [`BaseRAdapter$get_system_name()`](#method-BaseRAdapter-get_system_name)

- [`BaseRAdapter$get_adapter()`](#method-BaseRAdapter-get_adapter)

- [`BaseRAdapter$has_facets()`](#method-BaseRAdapter-has_facets)

- [`BaseRAdapter$is_patchwork()`](#method-BaseRAdapter-is_patchwork)

- [`BaseRAdapter$get_plot_calls()`](#method-BaseRAdapter-get_plot_calls)

- [`BaseRAdapter$clear_plot_calls()`](#method-BaseRAdapter-clear_plot_calls)

- [`BaseRAdapter$initialize_patching()`](#method-BaseRAdapter-initialize_patching)

- [`BaseRAdapter$restore_functions()`](#method-BaseRAdapter-restore_functions)

- [`BaseRAdapter$clone()`](#method-BaseRAdapter-clone)

------------------------------------------------------------------------

### Method `new()`

#### Usage

    BaseRAdapter$new()

------------------------------------------------------------------------

### Method `can_handle()`

#### Usage

    BaseRAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check (should be NULL for Base R)

#### Returns

TRUE if Base R plotting is active, FALSE otherwise Detect the type of a
single layer from Base R plot calls

------------------------------------------------------------------------

### Method `detect_layer_type()`

#### Usage

    BaseRAdapter$detect_layer_type(layer, plot_object = NULL)

#### Arguments

- `layer`:

  The plot call entry from our logger

- `plot_object`:

  The parent plot object (NULL for Base R)

#### Returns

String indicating the layer type (e.g., "bar", "dodged_bar",
"stacked_bar", "smooth", "line", "point") Check if a barplot call
represents a dodged bar plot

------------------------------------------------------------------------

### Method `is_dodged_barplot()`

#### Usage

    BaseRAdapter$is_dodged_barplot(args)

#### Arguments

- `args`:

  The arguments from the barplot call

#### Returns

TRUE if this is a dodged bar plot, FALSE otherwise Check if a barplot
call represents a stacked bar plot

------------------------------------------------------------------------

### Method `is_stacked_barplot()`

#### Usage

    BaseRAdapter$is_stacked_barplot(args)

#### Arguments

- `args`:

  The arguments from the barplot call

#### Returns

TRUE if this is a stacked bar plot, FALSE otherwise Create an
orchestrator for this system (Base R)

------------------------------------------------------------------------

### Method `create_orchestrator()`

#### Usage

    BaseRAdapter$create_orchestrator(plot_object = NULL)

#### Arguments

- `plot_object`:

  The plot object to process (NULL for Base R)

#### Returns

PlotOrchestrator instance Get the system name

------------------------------------------------------------------------

### Method `get_system_name()`

#### Usage

    BaseRAdapter$get_system_name()

#### Returns

System name string Get a reference to this adapter (for use by
orchestrator)

------------------------------------------------------------------------

### Method `get_adapter()`

#### Usage

    BaseRAdapter$get_adapter()

#### Returns

Self reference Check if plot has facets (Base R doesn't support facets)

------------------------------------------------------------------------

### Method `has_facets()`

#### Usage

    BaseRAdapter$has_facets(plot_object = NULL)

#### Arguments

- `plot_object`:

  The plot object (ignored for Base R)

#### Returns

FALSE (Base R doesn't support facets) Check if plot is a patchwork plot
(Base R doesn't support patchwork)

------------------------------------------------------------------------

### Method `is_patchwork()`

#### Usage

    BaseRAdapter$is_patchwork(plot_object = NULL)

#### Arguments

- `plot_object`:

  The plot object (ignored for Base R)

#### Returns

FALSE (Base R doesn't support patchwork) Get recorded plot calls for
processing

------------------------------------------------------------------------

### Method [`get_plot_calls()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/get_plot_calls.md)

#### Usage

    BaseRAdapter$get_plot_calls(device_id = grDevices::dev.cur())

#### Arguments

- `device_id`:

  Graphics device ID (defaults to current device)

#### Returns

List of recorded plot calls Clear recorded plot calls (for cleanup)

------------------------------------------------------------------------

### Method [`clear_plot_calls()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/clear_plot_calls.md)

#### Usage

    BaseRAdapter$clear_plot_calls(device_id = grDevices::dev.cur())

#### Arguments

- `device_id`:

  Graphics device ID (defaults to current device) Initialize function
  patching

------------------------------------------------------------------------

### Method `initialize_patching()`

#### Usage

    BaseRAdapter$initialize_patching()

#### Returns

NULL (invisible) Restore original functions

------------------------------------------------------------------------

### Method `restore_functions()`

#### Usage

    BaseRAdapter$restore_functions()

#### Returns

NULL (invisible)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
