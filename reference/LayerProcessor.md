# Abstract Layer Processor Interface

This is the abstract base class for all layer processors. It defines the
interface that all layer processors must implement.

## Public fields

- `layer_info`:

  Information about the layer

- `layer_info`:

  Information about the layer

## Methods

### Public methods

- [`LayerProcessor$new()`](#method-LayerProcessor-initialize)

- [`LayerProcessor$process()`](#method-LayerProcessor-process)

- [`LayerProcessor$extract_data()`](#method-LayerProcessor-extract_data)

- [`LayerProcessor$generate_selectors()`](#method-LayerProcessor-generate_selectors)

- [`LayerProcessor$get_layer_built_data()`](#method-LayerProcessor-get_layer_built_data)

- [`LayerProcessor$get_own_layer()`](#method-LayerProcessor-get_own_layer)

- [`LayerProcessor$find_layer_grob_tree()`](#method-LayerProcessor-find_layer_grob_tree)

- [`LayerProcessor$needs_reordering()`](#method-LayerProcessor-needs_reordering)

- [`LayerProcessor$reorder_layer_data()`](#method-LayerProcessor-reorder_layer_data)

- [`LayerProcessor$augment_plot()`](#method-LayerProcessor-augment_plot)

- [`LayerProcessor$needs_augmentation()`](#method-LayerProcessor-needs_augmentation)

- [`LayerProcessor$get_layer_index()`](#method-LayerProcessor-get_layer_index)

- [`LayerProcessor$is_flipped_layer()`](#method-LayerProcessor-is_flipped_layer)

- [`LayerProcessor$unflip_columns()`](#method-LayerProcessor-unflip_columns)

- [`LayerProcessor$is_horizontal_call()`](#method-LayerProcessor-is_horizontal_call)

- [`LayerProcessor$unflip_panel_params()`](#method-LayerProcessor-unflip_panel_params)

- [`LayerProcessor$swap_point_axes()`](#method-LayerProcessor-swap_point_axes)

- [`LayerProcessor$set_last_result()`](#method-LayerProcessor-set_last_result)

- [`LayerProcessor$get_last_result()`](#method-LayerProcessor-get_last_result)

- [`LayerProcessor$extract_layer_axes()`](#method-LayerProcessor-extract_layer_axes)

- [`LayerProcessor$clone()`](#method-LayerProcessor-clone)

------------------------------------------------------------------------

### `LayerProcessor$new()`

Initialize the layer processor

#### Usage

    LayerProcessor$new(layer_info)

#### Arguments

- `layer_info`:

  Information about the layer

------------------------------------------------------------------------

### `LayerProcessor$process()`

Process the layer (MUST be implemented by subclasses)

#### Usage

    LayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

#### Returns

List with data and selectors

------------------------------------------------------------------------

### `LayerProcessor$extract_data()`

Extract data from the layer (MUST be implemented by subclasses)

#### Usage

    LayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

#### Returns

Extracted data

------------------------------------------------------------------------

### `LayerProcessor$generate_selectors()`

Generate selectors for the layer (MUST be implemented by subclasses)

#### Usage

    LayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### `LayerProcessor$get_layer_built_data()`

Read this layer's rows out of the built plot.

Scoped to one panel when asked. A faceted plot puts every panel's rows
in one frame, so a layer that took all of them would describe the whole
facet grid as one series.

#### Usage

    LayerProcessor$get_layer_built_data(built, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A data frame of computed aesthetics, or NULL

------------------------------------------------------------------------

### `LayerProcessor$get_own_layer()`

Resolve the plot layer this processor was built for.

Every processor knows its index and several need the layer itself – for
its geom, its position or its own `data` – so the lookup lives here
rather than being copied into each. Answers NULL rather than erroring
when the index does not resolve, since a caller that cannot find its
layer has a reading to fall back on and no crash to justify.

#### Usage

    LayerProcessor$get_own_layer(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

The layer, or NULL when the index does not resolve

------------------------------------------------------------------------

### `LayerProcessor$find_layer_grob_tree()`

Find the grob tree ggplot2 drew for this layer.

ggplot2 names a layer's grob after its geom (`geom_smooth.gTree.5`), so
the tree is located by that prefix and, when the plot repeats the geom,
by this layer's position among the layers sharing it. Scoping to the
layer's own tree is what keeps a sibling layer's grobs out of whatever
the caller counts inside it.

Lives here rather than on one processor because two now need it and the
walk is the same walk – the argument that moved `get_own_layer()` and
`get_layer_built_data()` here before it. What differs between callers is
only which layer they are looking for, and that is the `target`
argument; the smooth processor passes a resolved index because it may
describe a layer other than its own, and everything else takes the
default.

#### Usage

    LayerProcessor$find_layer_grob_tree(plot, gt, panel_ctx = NULL, target = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for panel-scoped selector generation

- `target`:

  Index of the layer to find; defaults to this one's

#### Returns

The matching grob, or NULL

------------------------------------------------------------------------

### `LayerProcessor$needs_reordering()`

Check if this layer needs reordering (OPTIONAL - default: FALSE)

#### Usage

    LayerProcessor$needs_reordering()

#### Returns

Logical indicating if reordering is needed

------------------------------------------------------------------------

### `LayerProcessor$reorder_layer_data()`

Reorder layer data (OPTIONAL - default: no-op)

#### Usage

    LayerProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

#### Returns

Reordered data

------------------------------------------------------------------------

### `LayerProcessor$augment_plot()`

Augment the plot before building (OPTIONAL - default: no-op)

Called by the orchestrator before ggplot_build/ggplotGrob. Allows a
processor to inject additional geom layers (e.g., a boxplot inside a
violin) so they appear in the SVG and can be targeted by selectors.

#### Usage

    LayerProcessor$augment_plot(plot)

#### Arguments

- `plot`:

  The ggplot2 object to augment

#### Returns

The (possibly augmented) ggplot2 object

------------------------------------------------------------------------

### `LayerProcessor$needs_augmentation()`

Check if this processor needs to augment the plot

#### Usage

    LayerProcessor$needs_augmentation()

#### Returns

Logical

------------------------------------------------------------------------

### `LayerProcessor$get_layer_index()`

Get layer index

#### Usage

    LayerProcessor$get_layer_index()

#### Returns

Layer index

------------------------------------------------------------------------

### `LayerProcessor$is_flipped_layer()`

Is this layer drawn with its category axis running up `y`?

`ggplot(df, aes(y = g, x = n)) + geom_col()` is the ordinary spelling of
a horizontal bar chart.
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
marks such a layer `flipped_aes` and swaps which computed column holds
what, so a processor that reads `x` as the category and `y` as the
measure picks up exactly the wrong pair unless it asks first (#162,
\#184, \#186).

Lives here rather than on one processor because three of them need the
same answer, and because a processor that never asks it goes wrong
silently: both columns hold plausible values.

[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
is a different thing and answers `FALSE` here. It rotates the coordinate
system and leaves `flipped_aes` alone, so the data layout is genuinely
unflipped.

#### Usage

    LayerProcessor$is_flipped_layer(built = NULL)

#### Arguments

- `built`:

  A
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  result, or `NULL` when the caller has none – in which case the layer
  is treated as unflipped, since there is nothing to read the flag from.

#### Returns

`TRUE` when the category runs up the y axis.

------------------------------------------------------------------------

### `LayerProcessor$unflip_columns()`

Exchange a built layer's paired x and y columns

Swapping the pairs up front lets every branch downstream stay written
against one arrangement rather than each learning to ask which way round
it is – and a branch that forgot to ask would go wrong silently, since
both columns hold plausible numbers.

#### Usage

    LayerProcessor$unflip_columns(built_data)

#### Arguments

- `built_data`:

  One layer's built data.

#### Returns

The same frame with its x and y pairs exchanged.

------------------------------------------------------------------------

### `LayerProcessor$is_horizontal_call()`

Was this base R call drawn with `horiz = TRUE`?

The base R counterpart of @link is_flipped_layer:
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes the
orientation as an argument rather than marking the built layer, so the
answer is read back off the captured call.

#### Usage

    LayerProcessor$is_horizontal_call(layer_info = NULL)

#### Arguments

- `layer_info`:

  The captured layer information, or `NULL`.

#### Returns

`TRUE` when the bars run across the page.

------------------------------------------------------------------------

### `LayerProcessor$unflip_panel_params()`

Exchange a panel's x and y scales

So the break labels a processor reads come from the axis the categories
are actually drawn on. Both the scale objects and the flattened
`x.labels`/`y.labels` of older ggplot2 are swapped, since readers fall
back from one to the other.

#### Usage

    LayerProcessor$unflip_panel_params(panel_params)

#### Arguments

- `panel_params`:

  One entry of `built$layout$panel_params`.

#### Returns

The same list with its x and y entries exchanged.

------------------------------------------------------------------------

### `LayerProcessor$swap_point_axes()`

Put a horizontal layer's category and measure in the fields the bar
grammar reads them from.

Processors emit `x = category, y = measure`, which is the vertical
arrangement. A horizontal bar is read the other way round: MAIDR takes
`x` as the magnitude and `y` as the category when `orientation` is
`"horz"`, so the pair has to be exchanged on the way out. Left
unexchanged, the core looks for a number and finds a category name – no
magnitude to pitch, and an announcement that pairs the category axis
with the measure and the measure axis with the category name (#184).

Only the bar family wants this, which is why it is a step a processor
opts into rather than something the orchestrator applies to every
horizontal layer. An error bar keeps its category in `x` at both
orientations and lets `orientation` swap only which axis labels the
reading is announced against; a box carries quantiles and has no axis
assignment to exchange at all.

#### Usage

    LayerProcessor$swap_point_axes(data_points)

#### Arguments

- `data_points`:

  Points in `x = category, y = measure` form. A nested list – one series
  per element, as a grouped bar layer emits – is handled as well as a
  flat one.

#### Returns

The same points with `x` and `y` exchanged.

------------------------------------------------------------------------

### `LayerProcessor$set_last_result()`

Store the last processed result (used by orchestrator)

#### Usage

    LayerProcessor$set_last_result(result)

#### Arguments

- `result`:

  The result to store

------------------------------------------------------------------------

### `LayerProcessor$get_last_result()`

Get the last processed result

#### Usage

    LayerProcessor$get_last_result()

#### Returns

The last result

------------------------------------------------------------------------

### `LayerProcessor$extract_layer_axes()`

Extract axes labels for this specific layer

Returns axes in the canonical per-axis object schema:
`list(x = list(label = "..."), y = list(label = "..."))`.

Bare strings, top-level `format`/`min`/`max`/`tickStep`/ `fill`/`level`,
and any non-{x,y,z} keys are NOT permitted.

#### Usage

    LayerProcessor$extract_layer_axes(plot, layout)

#### Arguments

- `plot`:

  The ggplot object

- `layout`:

  Global layout with fallback axes

#### Returns

Named list with `x` and `y` AxisConfig objects

------------------------------------------------------------------------

### `LayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    LayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
