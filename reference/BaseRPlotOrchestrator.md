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

- [`BaseRPlotOrchestrator$canvas_size()`](#method-BaseRPlotOrchestrator-canvas_size)

- [`BaseRPlotOrchestrator$picture_size()`](#method-BaseRPlotOrchestrator-picture_size)

- [`BaseRPlotOrchestrator$picture_title()`](#method-BaseRPlotOrchestrator-picture_title)

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

Create an orchestrator for the calls recorded on a device

#### Usage

    BaseRPlotOrchestrator$new(
      device_id = grDevices::dev.cur(),
      width = NULL,
      height = NULL,
      asked = !is.null(width) || !is.null(height)
    )

#### Arguments

- `device_id`:

  Graphics device ID

- `width, height`:

  The size to draw the chart at, in inches, or `NULL` for maidr's own;
  see
  [`chart_canvas_size()`](https://r.maidr.ai/reference/chart_canvas_size.md)

- `asked`:

  Whether that size was asked for, by default when either side is given.
  A chart too small for a size not asked for is drawn larger
  ([`base_r_page_that_fits()`](https://r.maidr.ai/reference/base_r_page_that_fits.md));
  one too small for a size asked for stops.

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$detect_layers()`

Turn each recorded plot group into layer entries: one for its HIGH-level
call and one per LOW-level overlay

#### Usage

    BaseRPlotOrchestrator$detect_layers()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$analyze_single_layer()`

Describe one recorded call as a layer entry with its detected type

#### Usage

    BaseRPlotOrchestrator$analyze_single_layer(
      plot_call,
      layer_index,
      group = NULL
    )

#### Arguments

- `plot_call`:

  The recorded call

- `layer_index`:

  Index of the layer

- `group`:

  The recorded plot group holding the HIGH-level call

#### Returns

Layer information list

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$create_layer_processors()`

Create a processor for every layer of a known type

#### Usage

    BaseRPlotOrchestrator$create_layer_processors()

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$create_layer_processor()`

Create the processor for one layer

#### Usage

    BaseRPlotOrchestrator$create_layer_processor(layer_info)

#### Arguments

- `layer_info`:

  Layer information with the recorded call

#### Returns

A layer processor, or NULL for an unknown type

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

Run every layer processor and combine the results

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

Read the figure-level title, subtitle and axis labels from the recorded
HIGH-level calls

#### Usage

    BaseRPlotOrchestrator$extract_layout()

#### Returns

List

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$combine_layer_results()`

Combine the per-layer results into the subplot grid

#### Usage

    BaseRPlotOrchestrator$combine_layer_results(layer_results)

#### Arguments

- `layer_results`:

  List of per-layer results, one per processor

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$generate_maidr_data()`

Assemble the MAIDR data object for the figure

#### Usage

    BaseRPlotOrchestrator$generate_maidr_data()

#### Returns

List with an id and the subplots

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_layout()`

The figure-level layout read by `extract_layout()`

#### Usage

    BaseRPlotOrchestrator$get_layout()

#### Returns

List

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_combined_data()`

The combined per-layer data

#### Usage

    BaseRPlotOrchestrator$get_combined_data()

#### Returns

List

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_layer_processors()`

The processors created for the layers

#### Usage

    BaseRPlotOrchestrator$get_layer_processors()

#### Returns

List

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_layers()`

The detected layer entries

#### Usage

    BaseRPlotOrchestrator$get_layers()

#### Returns

List

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_plot_calls()`

The recorded plot calls

#### Usage

    BaseRPlotOrchestrator$get_plot_calls()

#### Returns

List

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_gtable()`

The gtable of the replayed drawing, built once and cached

#### Usage

    BaseRPlotOrchestrator$get_gtable()

#### Returns

A gtable, or NULL when nothing was recorded. Stops when the chart is too
small for R to draw at a size asked for (see
[`base_r_drawing_grob()`](https://r.maidr.ai/reference/base_r_drawing_grob.md));
one not asked for is enlarged to fit
([`base_r_page_that_fits()`](https://r.maidr.ai/reference/base_r_page_that_fits.md)).
Stops too when the chart cannot be drawn again, with the reason, every
time it is asked for: the chart is then drawn as a picture, with a
warning that says so
([`build_interactive_svg()`](https://r.maidr.ai/reference/build_interactive_svg.md)),
rather than empty.

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$canvas_size()`

The size the chart is drawn at

#### Usage

    BaseRPlotOrchestrator$canvas_size()

#### Returns

A named numeric vector, `width` and `height`, in inches

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$picture_size()`

The size a picture of the chart is drawn at, in place of a chart maidr
cannot read or export

The picture draws every recorded call again, as R drew them, and is held
to the chart's size as the chart is: too small for a size asked for, it
stops; too small for one no one asked for, it is drawn larger, with a
message naming the size. A picture R cannot draw at any size is drawn at
the chart's, as before: it shows what R draws of it.

#### Usage

    BaseRPlotOrchestrator$picture_size()

#### Returns

A named numeric vector, `width` and `height`, in inches

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$picture_title()`

The name of a picture of the chart, drawn in place of a chart that could
not be made interactive

The picture holds the page R shows, the last one, and is named by what
is drawn on it: the title R drew over its panels, with
`title(outer = TRUE)` or `mtext(outer = TRUE)` along the top; else, for
one panel, by its title, and for several, by each panel R drew in turn,
an untitled one called so: "2 panels: Sales 2023, Costs 2024". A panel's
title is its plot's, or the one
[`title()`](https://r.maidr.ai/reference/base-r-wrappers.md) gave it.
The chart's own title is its last titled panel's, from any page, which
would name a picture of several panels by one of them; and maidr's grid
of cells counts a panel spanning two cells twice, and an empty cell as a
panel.

#### Usage

    BaseRPlotOrchestrator$picture_title()

#### Returns

One string, or NULL when the chart has no title

------------------------------------------------------------------------

### `BaseRPlotOrchestrator$get_grob_for_layer()`

The grob a layer's processor searches for its selectors

#### Usage

    BaseRPlotOrchestrator$get_grob_for_layer(layer_index)

#### Arguments

- `layer_index`:

  Index of the layer

#### Returns

A grob, or NULL

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
