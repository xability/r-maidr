# Plot Orchestrator Class

Plot Orchestrator Class

Plot Orchestrator Class

## Details

This class orchestrates the detection and processing of multiple layers
in a ggplot2 object. It analyzes each layer individually and combines
the results into a comprehensive interactive plot.

## Public fields

- `plot`:

  The ggplot2 object being processed

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

- `plot`:

  The ggplot2 object being processed

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

- [`Ggplot2PlotOrchestrator$new()`](#method-Ggplot2PlotOrchestrator-new)

- [`Ggplot2PlotOrchestrator$detect_layers()`](#method-Ggplot2PlotOrchestrator-detect_layers)

- [`Ggplot2PlotOrchestrator$analyze_single_layer()`](#method-Ggplot2PlotOrchestrator-analyze_single_layer)

- [`Ggplot2PlotOrchestrator$determine_layer_type()`](#method-Ggplot2PlotOrchestrator-determine_layer_type)

- [`Ggplot2PlotOrchestrator$create_layer_processors()`](#method-Ggplot2PlotOrchestrator-create_layer_processors)

- [`Ggplot2PlotOrchestrator$create_layer_processor()`](#method-Ggplot2PlotOrchestrator-create_layer_processor)

- [`Ggplot2PlotOrchestrator$create_unified_layer_processor()`](#method-Ggplot2PlotOrchestrator-create_unified_layer_processor)

- [`Ggplot2PlotOrchestrator$process_layers()`](#method-Ggplot2PlotOrchestrator-process_layers)

- [`Ggplot2PlotOrchestrator$extract_layout()`](#method-Ggplot2PlotOrchestrator-extract_layout)

- [`Ggplot2PlotOrchestrator$combine_layer_results()`](#method-Ggplot2PlotOrchestrator-combine_layer_results)

- [`Ggplot2PlotOrchestrator$generate_maidr_data()`](#method-Ggplot2PlotOrchestrator-generate_maidr_data)

- [`Ggplot2PlotOrchestrator$get_gtable()`](#method-Ggplot2PlotOrchestrator-get_gtable)

- [`Ggplot2PlotOrchestrator$get_layout()`](#method-Ggplot2PlotOrchestrator-get_layout)

- [`Ggplot2PlotOrchestrator$get_combined_data()`](#method-Ggplot2PlotOrchestrator-get_combined_data)

- [`Ggplot2PlotOrchestrator$get_layer_processors()`](#method-Ggplot2PlotOrchestrator-get_layer_processors)

- [`Ggplot2PlotOrchestrator$get_layers()`](#method-Ggplot2PlotOrchestrator-get_layers)

- [`Ggplot2PlotOrchestrator$is_patchwork_plot()`](#method-Ggplot2PlotOrchestrator-is_patchwork_plot)

- [`Ggplot2PlotOrchestrator$is_faceted_plot()`](#method-Ggplot2PlotOrchestrator-is_faceted_plot)

- [`Ggplot2PlotOrchestrator$process_faceted_plot()`](#method-Ggplot2PlotOrchestrator-process_faceted_plot)

- [`Ggplot2PlotOrchestrator$process_patchwork_plot()`](#method-Ggplot2PlotOrchestrator-process_patchwork_plot)

- [`Ggplot2PlotOrchestrator$clone()`](#method-Ggplot2PlotOrchestrator-clone)

------------------------------------------------------------------------

### Method `new()`

#### Usage

    Ggplot2PlotOrchestrator$new(plot)

------------------------------------------------------------------------

### Method `detect_layers()`

#### Usage

    Ggplot2PlotOrchestrator$detect_layers()

------------------------------------------------------------------------

### Method `analyze_single_layer()`

#### Usage

    Ggplot2PlotOrchestrator$analyze_single_layer(layer, layer_index)

------------------------------------------------------------------------

### Method `determine_layer_type()`

#### Usage

    Ggplot2PlotOrchestrator$determine_layer_type(plot, layer_index)

------------------------------------------------------------------------

### Method `create_layer_processors()`

#### Usage

    Ggplot2PlotOrchestrator$create_layer_processors()

------------------------------------------------------------------------

### Method `create_layer_processor()`

#### Usage

    Ggplot2PlotOrchestrator$create_layer_processor(layer_info)

------------------------------------------------------------------------

### Method `create_unified_layer_processor()`

#### Usage

    Ggplot2PlotOrchestrator$create_unified_layer_processor(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Layer processor instance

------------------------------------------------------------------------

### Method `process_layers()`

#### Usage

    Ggplot2PlotOrchestrator$process_layers()

------------------------------------------------------------------------

### Method `extract_layout()`

#### Usage

    Ggplot2PlotOrchestrator$extract_layout()

------------------------------------------------------------------------

### Method `combine_layer_results()`

#### Usage

    Ggplot2PlotOrchestrator$combine_layer_results(layer_results)

------------------------------------------------------------------------

### Method `generate_maidr_data()`

#### Usage

    Ggplot2PlotOrchestrator$generate_maidr_data()

------------------------------------------------------------------------

### Method `get_gtable()`

#### Usage

    Ggplot2PlotOrchestrator$get_gtable()

------------------------------------------------------------------------

### Method `get_layout()`

#### Usage

    Ggplot2PlotOrchestrator$get_layout()

------------------------------------------------------------------------

### Method `get_combined_data()`

#### Usage

    Ggplot2PlotOrchestrator$get_combined_data()

------------------------------------------------------------------------

### Method `get_layer_processors()`

#### Usage

    Ggplot2PlotOrchestrator$get_layer_processors()

------------------------------------------------------------------------

### Method `get_layers()`

#### Usage

    Ggplot2PlotOrchestrator$get_layers()

------------------------------------------------------------------------

### Method `is_patchwork_plot()`

Check if the plot is a patchwork composition

#### Usage

    Ggplot2PlotOrchestrator$is_patchwork_plot()

#### Returns

Logical indicating if the plot is a patchwork plot

------------------------------------------------------------------------

### Method `is_faceted_plot()`

Check if the plot is faceted

#### Usage

    Ggplot2PlotOrchestrator$is_faceted_plot()

#### Returns

Logical indicating if the plot is faceted

------------------------------------------------------------------------

### Method `process_faceted_plot()`

Process a faceted plot using utility functions

#### Usage

    Ggplot2PlotOrchestrator$process_faceted_plot()

#### Returns

NULL (sets internal state)

------------------------------------------------------------------------

### Method `process_patchwork_plot()`

Process a patchwork multipanel plot using utility functions

#### Usage

    Ggplot2PlotOrchestrator$process_patchwork_plot()

#### Returns

NULL (sets internal state)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
