# Base R System Adapter

Adapter for the Base R plotting system. This adapter uses function
patching to intercept Base R plotting calls and detect plot types.

## Format

An R6 class inheriting from SystemAdapter

## Super class

[`SystemAdapter`](https://r.maidr.ai/reference/SystemAdapter.md) -\>
`BaseRAdapter`

## Methods

### Public methods

- [`BaseRAdapter$new()`](#method-BaseRAdapter-initialize)

- [`BaseRAdapter$formula_frame_missing()`](#method-BaseRAdapter-formula_frame_missing)

- [`BaseRAdapter$formula_call()`](#method-BaseRAdapter-formula_call)

- [`BaseRAdapter$formula_scatter_readable()`](#method-BaseRAdapter-formula_scatter_readable)

- [`BaseRAdapter$can_handle()`](#method-BaseRAdapter-can_handle)

- [`BaseRAdapter$detect_layer_type()`](#method-BaseRAdapter-detect_layer_type)

- [`BaseRAdapter$is_dodged_barplot()`](#method-BaseRAdapter-is_dodged_barplot)

- [`BaseRAdapter$is_stacked_barplot()`](#method-BaseRAdapter-is_stacked_barplot)

- [`BaseRAdapter$is_normalized_barplot()`](#method-BaseRAdapter-is_normalized_barplot)

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

### `BaseRAdapter$new()`

Initialize the Base R adapter

#### Usage

    BaseRAdapter$new()

------------------------------------------------------------------------

### `BaseRAdapter$formula_frame_missing()`

Was a formula call recorded without the frame it drew from?

A formula reader takes its rows from the model frame kept at record
time. When that frame could not be built – a `subset` written as an
expression with nothing to evaluate it in, a `data` that no longer
resolves – the reader has nothing to announce, and a claimed layer with
nothing in it exports as an interactive chart that says nothing.
Declining the type sends the chart to the picture instead.

#### Usage

    BaseRAdapter$formula_frame_missing(layer)

#### Arguments

- `layer`:

  The recorded call entry

#### Returns

TRUE when the call carries a formula but no frame

------------------------------------------------------------------------

### `BaseRAdapter$formula_call()`

Was the call handed a formula?

Either written in the call, or – `fmla <- y ~ x; plot(fmla)` – bound to
a name the recorder resolved.

#### Usage

    BaseRAdapter$formula_call(layer)

#### Arguments

- `layer`:

  The recorded call entry

#### Returns

TRUE when the call carries a formula

------------------------------------------------------------------------

### `BaseRAdapter$formula_scatter_readable()`

Does a recorded formula
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draw a
numeric scatter?

`plot.formula()` draws a scatter only for a numeric response over one
numeric predictor; a factor predictor reaches `plot.factor()` and a box
plot, and a longer right-hand side is
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html) over
the first term. Only the two-column numeric frame is read as points.

#### Usage

    BaseRAdapter$formula_scatter_readable(layer)

#### Arguments

- `layer`:

  The recorded call entry

#### Returns

TRUE when the frame is a numeric pair

------------------------------------------------------------------------

### `BaseRAdapter$can_handle()`

Check if this adapter can handle a plot object

#### Usage

    BaseRAdapter$can_handle(plot_object)

#### Arguments

- `plot_object`:

  The plot object to check (should be NULL for Base R)

#### Returns

TRUE if Base R plotting is active, FALSE otherwise

------------------------------------------------------------------------

### `BaseRAdapter$detect_layer_type()`

Detect the type of a single layer from Base R plot calls

#### Usage

    BaseRAdapter$detect_layer_type(layer, plot_object = NULL)

#### Arguments

- `layer`:

  The plot call entry from our logger

- `plot_object`:

  The parent plot object (NULL for Base R)

#### Returns

String indicating the layer type (e.g., "bar", "dodged_bar",
"stacked_bar", "smooth", "line", "point")

------------------------------------------------------------------------

### `BaseRAdapter$is_dodged_barplot()`

Check if a barplot call represents a dodged bar plot

#### Usage

    BaseRAdapter$is_dodged_barplot(args)

#### Arguments

- `args`:

  The arguments from the barplot call

#### Returns

TRUE if this is a dodged bar plot, FALSE otherwise

------------------------------------------------------------------------

### `BaseRAdapter$is_stacked_barplot()`

Check if a barplot call represents a stacked bar plot

#### Usage

    BaseRAdapter$is_stacked_barplot(args)

#### Arguments

- `args`:

  The arguments from the barplot call

#### Returns

TRUE if this is a stacked bar plot, FALSE otherwise

------------------------------------------------------------------------

### `BaseRAdapter$is_normalized_barplot()`

Check if a barplot call draws a 100% stacked bar

Base R has no `position = "fill"` to read:
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes no
normalisation argument at all, and the idiomatic way to draw a 100%
stacked bar is to normalise the matrix first, as
`barplot(prop.table(m, 2))`. The only signal left is the drawn geometry.

So this reads what the chart shows rather than guessing what the author
meant, and the two are the same thing here: when every column sums to 1,
every bar is drawn to a common full height and each segment is that
category's share. A chart like that IS a 100% stacked bar whatever the
numbers were before they reached
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md).

Deliberately narrow. It does not also accept columns summing to 100,
because a matrix of raw counts can total 100 by coincidence and nothing
about the drawing would distinguish that from percentages. And it needs
two or more rows, because a single series stacked against nothing is not
a stack.

#### Usage

    BaseRAdapter$is_normalized_barplot(args)

#### Arguments

- `args`:

  The arguments from the barplot call

#### Returns

TRUE if every column of the height matrix sums to 1

------------------------------------------------------------------------

### `BaseRAdapter$create_orchestrator()`

Create an orchestrator for this system (Base R)

#### Usage

    BaseRAdapter$create_orchestrator(plot_object = NULL)

#### Arguments

- `plot_object`:

  The plot object to process (NULL for Base R)

#### Returns

PlotOrchestrator instance

------------------------------------------------------------------------

### `BaseRAdapter$get_system_name()`

Get the system name

#### Usage

    BaseRAdapter$get_system_name()

#### Returns

System name string

------------------------------------------------------------------------

### `BaseRAdapter$get_adapter()`

Get a reference to this adapter (for use by orchestrator)

#### Usage

    BaseRAdapter$get_adapter()

#### Returns

Self reference

------------------------------------------------------------------------

### `BaseRAdapter$has_facets()`

Check if plot has facets (Base R doesn't support facets)

#### Usage

    BaseRAdapter$has_facets(plot_object = NULL)

#### Arguments

- `plot_object`:

  The plot object (ignored for Base R)

#### Returns

FALSE (Base R doesn't support facets)

------------------------------------------------------------------------

### `BaseRAdapter$is_patchwork()`

Check if plot is a patchwork plot (Base R doesn't support patchwork)

#### Usage

    BaseRAdapter$is_patchwork(plot_object = NULL)

#### Arguments

- `plot_object`:

  The plot object (ignored for Base R)

#### Returns

FALSE (Base R doesn't support patchwork)

------------------------------------------------------------------------

### `BaseRAdapter$get_plot_calls()`

Get recorded plot calls for processing

#### Usage

    BaseRAdapter$get_plot_calls(device_id = grDevices::dev.cur())

#### Arguments

- `device_id`:

  Graphics device ID (defaults to current device)

#### Returns

List of recorded plot calls

------------------------------------------------------------------------

### `BaseRAdapter$clear_plot_calls()`

Clear recorded plot calls (for cleanup)

#### Usage

    BaseRAdapter$clear_plot_calls(device_id = grDevices::dev.cur())

#### Arguments

- `device_id`:

  Graphics device ID (defaults to current device)

------------------------------------------------------------------------

### `BaseRAdapter$initialize_patching()`

Initialize function patching

#### Usage

    BaseRAdapter$initialize_patching()

#### Returns

NULL (invisible)

------------------------------------------------------------------------

### `BaseRAdapter$restore_functions()`

Restore original functions

#### Usage

    BaseRAdapter$restore_functions()

#### Returns

NULL (invisible)

------------------------------------------------------------------------

### `BaseRAdapter$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRAdapter$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
