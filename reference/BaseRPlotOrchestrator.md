# Base R Plot Orchestrator Class

Base R Plot Orchestrator Class

Base R Plot Orchestrator Class

## Details

This class orchestrates the detection and processing of multiple layers
in Base R plots. It analyzes each recorded plot call individually and
combines the results into a comprehensive interactive plot.

## Public fields

- `plot_calls`:

  List of recorded Base R plot calls

- `layers`:

  List of detected layer information

- `layer_processors`:

  List of layer-specific processors

- `combined_data`:

  Combined data from all layers

- `combined_selectors`:

  Combined selectors from all layers

- `layout`:

  Layout information from the plot

## Active bindings

- `plot_calls`:

  List of recorded Base R plot calls

- `layers`:

  List of detected layer information

- `layer_processors`:

  List of layer-specific processors

- `combined_data`:

  Combined data from all layers

- `combined_selectors`:

  Combined selectors from all layers

- `layout`:

  Layout information from the plot

## Methods

### Public methods

- [`BaseRPlotOrchestrator$new()`](#method-BaseRPlotOrchestrator-new)

- [`BaseRPlotOrchestrator$detect_layers()`](#method-BaseRPlotOrchestrator-detect_layers)

- [`BaseRPlotOrchestrator$analyze_single_layer()`](#method-BaseRPlotOrchestrator-analyze_single_layer)

- [`BaseRPlotOrchestrator$create_layer_processors()`](#method-BaseRPlotOrchestrator-create_layer_processors)

- [`BaseRPlotOrchestrator$create_layer_processor()`](#method-BaseRPlotOrchestrator-create_layer_processor)

- [`BaseRPlotOrchestrator$create_unified_layer_processor()`](#method-BaseRPlotOrchestrator-create_unified_layer_processor)

- [`BaseRPlotOrchestrator$process_layers()`](#method-BaseRPlotOrchestrator-process_layers)

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

- [`BaseRPlotOrchestrator$has_unsupported_layers()`](#method-BaseRPlotOrchestrator-has_unsupported_layers)

- [`BaseRPlotOrchestrator$should_fallback()`](#method-BaseRPlotOrchestrator-should_fallback)

- [`BaseRPlotOrchestrator$clone()`](#method-BaseRPlotOrchestrator-clone)

------------------------------------------------------------------------

### Method `new()`

#### Usage

    BaseRPlotOrchestrator$new(device_id = grDevices::dev.cur())

------------------------------------------------------------------------

### Method `detect_layers()`

#### Usage

    BaseRPlotOrchestrator$detect_layers()

------------------------------------------------------------------------

### Method `analyze_single_layer()`

#### Usage

    BaseRPlotOrchestrator$analyze_single_layer(
      plot_call,
      layer_index,
      group = NULL
    )

------------------------------------------------------------------------

### Method `create_layer_processors()`

#### Usage

    BaseRPlotOrchestrator$create_layer_processors()

------------------------------------------------------------------------

### Method `create_layer_processor()`

#### Usage

    BaseRPlotOrchestrator$create_layer_processor(layer_info)

------------------------------------------------------------------------

### Method `create_unified_layer_processor()`

#### Usage

    BaseRPlotOrchestrator$create_unified_layer_processor(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Layer processor instance

------------------------------------------------------------------------

### Method `process_layers()`

#### Usage

    BaseRPlotOrchestrator$process_layers()

------------------------------------------------------------------------

### Method `extract_layout()`

#### Usage

    BaseRPlotOrchestrator$extract_layout()

------------------------------------------------------------------------

### Method `combine_layer_results()`

#### Usage

    BaseRPlotOrchestrator$combine_layer_results(layer_results)

------------------------------------------------------------------------

### Method `generate_maidr_data()`

#### Usage

    BaseRPlotOrchestrator$generate_maidr_data()

------------------------------------------------------------------------

### Method `get_layout()`

#### Usage

    BaseRPlotOrchestrator$get_layout()

------------------------------------------------------------------------

### Method `get_combined_data()`

#### Usage

    BaseRPlotOrchestrator$get_combined_data()

------------------------------------------------------------------------

### Method `get_layer_processors()`

#### Usage

    BaseRPlotOrchestrator$get_layer_processors()

------------------------------------------------------------------------

### Method `get_layers()`

#### Usage

    BaseRPlotOrchestrator$get_layers()

------------------------------------------------------------------------

### Method [`get_plot_calls()`](https://r.maidr.ai/reference/get_plot_calls.md)

#### Usage

    BaseRPlotOrchestrator$get_plot_calls()

------------------------------------------------------------------------

### Method `get_gtable()`

#### Usage

    BaseRPlotOrchestrator$get_gtable()

------------------------------------------------------------------------

### Method `get_grob_for_layer()`

#### Usage

    BaseRPlotOrchestrator$get_grob_for_layer(layer_index)

------------------------------------------------------------------------

### Method `has_unsupported_layers()`

Check if any HIGH-level layers are unsupported (unknown type)

#### Usage

    BaseRPlotOrchestrator$has_unsupported_layers()

#### Returns

Logical indicating if there are unsupported layers

------------------------------------------------------------------------

### Method `should_fallback()`

Determine if the plot should fall back to image rendering

#### Usage

    BaseRPlotOrchestrator$should_fallback()

#### Returns

Logical indicating if fallback should be used

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRPlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
