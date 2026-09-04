# Base R Plot Orchestrator Class

This class orchestrates the detection and processing of multiple layers
in Base R plots. It analyzes each recorded plot call individually and
combines the results into a comprehensive interactive plot.

## Methods

### Public methods

- [`BaseRPlotOrchestrator$new()`](#method-BaseRPlotOrchestrator-initialize)

- [`BaseRPlotOrchestrator$detect_layers()`](#method-BaseRPlotOrchestrator-detect_layers)

- [`BaseRPlotOrchestrator$analyze_single_layer()`](#method-BaseRPlotOrchestrator-analyze_single_layer)

- [`BaseRPlotOrchestrator$create_layer_processors()`](#method-BaseRPlotOrchestrator-create_layer_processors)

- [`BaseRPlotOrchestrator$create_layer_processor()`](#method-BaseRPlotOrchestrator-create_layer_processor)

- [`BaseRPlotOrchestrator$create_unified_layer_processor()`](#method-BaseRPlotOrchestrator-create_unified_layer_processor)

- [`BaseRPlotOrchestrator$process_layers()`](#method-BaseRPlotOrchestrator-process_layers)

- [`BaseRPlotOrchestrator$extract_format_config_from_axis_calls()`](#method-BaseRPlotOrchestrator-extract_format_config_from_axis_calls)

- [`BaseRPlotOrchestrator$extract_layout()`](#method-BaseRPlotOrchestrator-extract_layout)

- [`BaseRPlotOrchestrator$combine_layer_results()`](#method-BaseRPlotOrchestrator-combine_layer_results)

- [`BaseRPlotOrchestrator$generate_maidr_data()`](#method-BaseRPlotOrchestrator-generate_maidr_data)

- [`BaseRPlotOrchestrator$get_layout()`](#method-BaseRPlotOrchestrator-get_layout)

- [`BaseRPlotOrchestrator$get_combined_data()`](#method-BaseRPlotOrchestrator-get_combined_data)

- [`BaseRPlotOrchestrator$get_layer_processors()`](#method-BaseRPlotOrchestrator-get_layer_processors)

- [`BaseRPlotOrchestrator$get_layers()`](#method-BaseRPlotOrchestrator-get_layers)

- [`BaseRPlotOrchestrator$get_plot_calls()`](#method-BaseRPlotOrchestrator-get_plot_calls)

- [`BaseRPlotOrchestrator$get_gtable()`](#method-BaseRPlotOrchestrator-get_gtable)

- [`BaseRPlotOrchestrator$get_grob_for_layer()`](#method-BaseRPlotOrchestrator-get_grob_for_layer)

- [`BaseRPlotOrchestrator$unsupported_layer_flags()`](#method-BaseRPlotOrchestrator-unsupported_layer_flags)

- [`BaseRPlotOrchestrator$has_unsupported_layers()`](#method-BaseRPlotOrchestrator-has_unsupported_layers)

- [`BaseRPlotOrchestrator$unsupported_group_indices()`](#method-BaseRPlotOrchestrator-unsupported_group_indices)

- [`BaseRPlotOrchestrator$resolve_fallback_scope()`](#method-BaseRPlotOrchestrator-resolve_fallback_scope)

- [`BaseRPlotOrchestrator$is_group_scoped_out()`](#method-BaseRPlotOrchestrator-is_group_scoped_out)

- [`BaseRPlotOrchestrator$fallback_panels()`](#method-BaseRPlotOrchestrator-fallback_panels)

- [`BaseRPlotOrchestrator$should_fallback()`](#method-BaseRPlotOrchestrator-should_fallback)

- [`BaseRPlotOrchestrator$clone()`](#method-BaseRPlotOrchestrator-clone)

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$new()`

#### Usage

    BaseRPlotOrchestrator$new(device_id = grDevices::dev.cur())

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$detect_layers()`

#### Usage

    BaseRPlotOrchestrator$detect_layers()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$analyze_single_layer()`

#### Usage

    BaseRPlotOrchestrator$analyze_single_layer(
      plot_call,
      layer_index,
      group = NULL
    )

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$create_layer_processors()`

#### Usage

    BaseRPlotOrchestrator$create_layer_processors()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$create_layer_processor()`

#### Usage

    BaseRPlotOrchestrator$create_layer_processor(layer_info)

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$create_unified_layer_processor()`

Unified layer processor creation - used by all plot types

#### Usage

    BaseRPlotOrchestrator$create_unified_layer_processor(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Layer processor instance

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$process_layers()`

#### Usage

    BaseRPlotOrchestrator$process_layers()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$extract_format_config_from_axis_calls()`

Extract Format Configuration from axis() Calls

Scans logged axis() calls for format config stored by the axis wrapper.
The wrapper stores .maidr_format_config when labels is a scales::
function.

#### Usage

    BaseRPlotOrchestrator$extract_format_config_from_axis_calls()

#### Returns

A list with x and/or y format configurations, or NULL

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$extract_layout()`

#### Usage

    BaseRPlotOrchestrator$extract_layout()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$combine_layer_results()`

#### Usage

    BaseRPlotOrchestrator$combine_layer_results(layer_results)

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$generate_maidr_data()`

#### Usage

    BaseRPlotOrchestrator$generate_maidr_data()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_layout()`

#### Usage

    BaseRPlotOrchestrator$get_layout()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_combined_data()`

#### Usage

    BaseRPlotOrchestrator$get_combined_data()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_layer_processors()`

#### Usage

    BaseRPlotOrchestrator$get_layer_processors()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_layers()`

#### Usage

    BaseRPlotOrchestrator$get_layers()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_plot_calls()`

#### Usage

    BaseRPlotOrchestrator$get_plot_calls()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_gtable()`

#### Usage

    BaseRPlotOrchestrator$get_gtable()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_grob_for_layer()`

#### Usage

    BaseRPlotOrchestrator$get_grob_for_layer(layer_index)

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$unsupported_layer_flags()`

Flag each detected layer maidr cannot process

Decorations carry no data of their own; leaving them out of the
interactive output loses nothing. Data-bearing LOW-level overlays
(polygon, rect, segments, ...) with no processor would silently
disappear from the accessible output, so they count as unsupported.

#### Usage

    BaseRPlotOrchestrator$unsupported_layer_flags()

#### Returns

Logical vector, one entry per detected layer

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$has_unsupported_layers()`

Check if any HIGH-level layers are unsupported (unknown type)

#### Usage

    BaseRPlotOrchestrator$has_unsupported_layers()

#### Returns

Logical indicating if there are unsupported layers

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$unsupported_group_indices()`

Plot groups holding a layer maidr cannot process

#### Usage

    BaseRPlotOrchestrator$unsupported_group_indices()

#### Returns

Integer vector of plot-group indices, in ascending order

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$resolve_fallback_scope()`

Work out how far an unsupported layer reaches

An unsupported LOW-level overlay sits on top of a chart maidr does
understand, so it only makes the panel that owns it undescribable. In a
multi-panel figure the other panels are drawn from their own calls and
stay fully accessible, so the fallback is scoped to the affected panels.
It widens to the whole figure when there is nothing left to scope to: a
single-panel figure, a figure whose every visible panel is affected, an
unsupported call that belongs to no panel of the exported page, or an
unsupported HIGH-level call.

#### Usage

    BaseRPlotOrchestrator$resolve_fallback_scope()

#### Returns

Invisible NULL; the scope is cached on the orchestrator

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$is_group_scoped_out()`

Check whether a plot group is scoped out of the payload

#### Usage

    BaseRPlotOrchestrator$is_group_scoped_out(group_index)

#### Arguments

- `group_index`:

  Plot-group index to test

#### Returns

TRUE when the group's panel falls back on its own

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$fallback_panels()`

Panels rendered without accessible data

#### Usage

    BaseRPlotOrchestrator$fallback_panels()

#### Returns

Integer vector of 1-based panel numbers, empty when the whole figure
renders normally or falls back as a whole

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$should_fallback()`

Determine if the plot should fall back to image rendering

#### Usage

    BaseRPlotOrchestrator$should_fallback()

#### Returns

Logical indicating if fallback should be used

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
