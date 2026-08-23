# Plot Orchestrator Class

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

- [`Ggplot2PlotOrchestrator$new()`](#method-Ggplot2PlotOrchestrator-initialize)

- [`Ggplot2PlotOrchestrator$detect_layers()`](#method-Ggplot2PlotOrchestrator-detect_layers)

- [`Ggplot2PlotOrchestrator$skip_layers_that_drew_nothing()`](#method-Ggplot2PlotOrchestrator-skip_layers_that_drew_nothing)

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

- [`Ggplot2PlotOrchestrator$has_unsupported_layers()`](#method-Ggplot2PlotOrchestrator-has_unsupported_layers)

- [`Ggplot2PlotOrchestrator$should_fallback()`](#method-Ggplot2PlotOrchestrator-should_fallback)

- [`Ggplot2PlotOrchestrator$clone()`](#method-Ggplot2PlotOrchestrator-clone)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$new()`

#### Usage

    Ggplot2PlotOrchestrator$new(plot)

#### Arguments

- `plot`:

  The ggplot2 object being processed

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$detect_layers()`

#### Usage

    Ggplot2PlotOrchestrator$detect_layers()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$skip_layers_that_drew_nothing()`

Retag every layer that drew no rows as `"skip"`.

A layer can be typed perfectly well and still have nothing in it – a
`data =` filtered to nothing, a stat that dropped every row, a facet
arrangement in which one layer's data is empty, a **Suggests** package
absent so the stat could not run. It then reaches the schema as a layer
a reader can walk into and find nothing in. Measured on ten points, the
second layer drawn from `d[0, ]`:


    geom_point()   point(0)      an empty layer of points
    geom_col()     bar(0)        an empty layer of bars
    geom_line()    line(1x0)     one series, holding nothing
    geom_smooth()  smooth(1x0)   one series, holding nothing

Asked here rather than in `detect_layer_type()` because emptiness is not
a fact about what *kind* of chart a layer is, and because the classifier
runs per layer: one
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
for the whole pass costs a chart ~37 ms once, where asking per layer
would multiply it. `"skip"` rather than a fourth answer, because that is
the tag the rest of the orchestrator already understands – including the
\#176 guard, so a chart whose *only* layer is empty falls back to an
image rather than announcing itself as interactive with nothing in it.

A build that cannot answer changes nothing. That is the same posture
`layer_drew_nothing()` takes: a plot that will not build is a bigger
problem than this, and it is about to be met by whatever else needs the
build.

#### Usage

    Ggplot2PlotOrchestrator$skip_layers_that_drew_nothing()

#### Returns

NULL, invisibly. Rewrites `private$.layers` in place.

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$analyze_single_layer()`

#### Usage

    Ggplot2PlotOrchestrator$analyze_single_layer(layer, layer_index)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$determine_layer_type()`

#### Usage

    Ggplot2PlotOrchestrator$determine_layer_type(plot, layer_index)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$create_layer_processors()`

#### Usage

    Ggplot2PlotOrchestrator$create_layer_processors()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$create_layer_processor()`

#### Usage

    Ggplot2PlotOrchestrator$create_layer_processor(layer_info)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$create_unified_layer_processor()`

Unified layer processor creation - used by all plot types

#### Usage

    Ggplot2PlotOrchestrator$create_unified_layer_processor(layer_info)

#### Arguments

- `layer_info`:

  Layer information

#### Returns

Layer processor instance

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$process_layers()`

#### Usage

    Ggplot2PlotOrchestrator$process_layers()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$extract_layout()`

#### Usage

    Ggplot2PlotOrchestrator$extract_layout(built = NULL)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$combine_layer_results()`

#### Usage

    Ggplot2PlotOrchestrator$combine_layer_results(layer_results)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$generate_maidr_data()`

#### Usage

    Ggplot2PlotOrchestrator$generate_maidr_data()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$get_gtable()`

#### Usage

    Ggplot2PlotOrchestrator$get_gtable()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$get_layout()`

#### Usage

    Ggplot2PlotOrchestrator$get_layout()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$get_combined_data()`

#### Usage

    Ggplot2PlotOrchestrator$get_combined_data()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$get_layer_processors()`

#### Usage

    Ggplot2PlotOrchestrator$get_layer_processors()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$get_layers()`

#### Usage

    Ggplot2PlotOrchestrator$get_layers()

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$is_patchwork_plot()`

Check if the plot is a patchwork composition

#### Usage

    Ggplot2PlotOrchestrator$is_patchwork_plot()

#### Returns

Logical indicating if the plot is a patchwork plot

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$is_faceted_plot()`

Check if the plot is faceted

#### Usage

    Ggplot2PlotOrchestrator$is_faceted_plot()

#### Returns

Logical indicating if the plot is faceted

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$process_faceted_plot()`

Process a faceted plot using utility functions

#### Usage

    Ggplot2PlotOrchestrator$process_faceted_plot()

#### Returns

NULL (sets internal state)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$process_patchwork_plot()`

Process a patchwork multipanel plot using utility functions

#### Usage

    Ggplot2PlotOrchestrator$process_patchwork_plot()

#### Returns

NULL (sets internal state)

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$has_unsupported_layers()`

Check if any layers are unsupported (unknown type)

#### Usage

    Ggplot2PlotOrchestrator$has_unsupported_layers()

#### Returns

Logical indicating if there are unsupported layers

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$should_fallback()`

Determine if the plot should fall back to image rendering

#### Usage

    Ggplot2PlotOrchestrator$should_fallback()

#### Returns

Logical indicating if fallback should be used

------------------------------------------------------------------------

### `Ggplot2PlotOrchestrator$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PlotOrchestrator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
