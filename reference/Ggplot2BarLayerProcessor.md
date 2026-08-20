# Bar Layer Processor

Processes bar plot layers with complete logic included

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2BarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2BarLayerProcessor$process()`](#method-Ggplot2BarLayerProcessor-process)

- [`Ggplot2BarLayerProcessor$is_flipped()`](#method-Ggplot2BarLayerProcessor-is_flipped)

- [`Ggplot2BarLayerProcessor$unflip_mapping()`](#method-Ggplot2BarLayerProcessor-unflip_mapping)

- [`Ggplot2BarLayerProcessor$needs_reordering()`](#method-Ggplot2BarLayerProcessor-needs_reordering)

- [`Ggplot2BarLayerProcessor$reorder_layer_data()`](#method-Ggplot2BarLayerProcessor-reorder_layer_data)

- [`Ggplot2BarLayerProcessor$extract_data()`](#method-Ggplot2BarLayerProcessor-extract_data)

- [`Ggplot2BarLayerProcessor$format_x_value()`](#method-Ggplot2BarLayerProcessor-format_x_value)

- [`Ggplot2BarLayerProcessor$panel_x_is_discrete()`](#method-Ggplot2BarLayerProcessor-panel_x_is_discrete)

- [`Ggplot2BarLayerProcessor$map_discrete_x()`](#method-Ggplot2BarLayerProcessor-map_discrete_x)

- [`Ggplot2BarLayerProcessor$map_continuous_x()`](#method-Ggplot2BarLayerProcessor-map_continuous_x)

- [`Ggplot2BarLayerProcessor$generate_selectors()`](#method-Ggplot2BarLayerProcessor-generate_selectors)

- [`Ggplot2BarLayerProcessor$clone()`](#method-Ggplot2BarLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$process()`

#### Usage

    Ggplot2BarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
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

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$is_flipped()`

Is this layer's category axis `y` rather than `x`?

`ggplot(df, aes(y = g, x = n)) + geom_col()` is the ordinary spelling of
a horizontal bar chart, and
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
marks it `flipped_aes` and swaps which computed column holds what.
Everything below reads `x` as the category and `y` as the measure, so on
a flipped layer it picked up exactly the wrong pair:
`apple/banana/cherry` at `30/70/50` came out as category `"30"` with
value `1`, category `"50"` with value `3` and category `"70"` with value
`2` – the labels gone, the values replaced by factor codes, and the rows
resorted by the measure (#162).

[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
is not this. It rotates the coordinate system and leaves `flipped_aes`
alone, so its data layout is genuinely unflipped, and it is reported
`vert` today. That question spans every processor.

Should it ever be answered here, the key and the point layout have to
move together: `"horz"` and the vertical `x = category, y = measure`
pairing is precisely the combination \#184 was about, and a
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
chart currently reads correctly only because both halves are left in
their vertical form. That is what @link swap_point_axes being driven
from this same answer is for.

#### Usage

    Ggplot2BarLayerProcessor$is_flipped(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object.

- `built`:

  Its
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  result, when the caller has one.

#### Returns

`TRUE` when the category runs up the y axis.

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$unflip_mapping()`

Exchange a plot's x and y aesthetics

Returns a copy: the mapping is only read to recover the category's
column name, and the caller's plot is still wanted unswapped for
selectors and axis labels.

#### Usage

    Ggplot2BarLayerProcessor$unflip_mapping(plot)

#### Arguments

- `plot`:

  The ggplot2 object.

#### Returns

A copy whose plot-level and layer-level x/y mappings are swapped.

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$needs_reordering()`

#### Usage

    Ggplot2BarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$reorder_layer_data()`

#### Usage

    Ggplot2BarLayerProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$extract_data()`

#### Usage

    Ggplot2BarLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$format_x_value()`

Format an x-axis value as character.

Date / POSIXct / POSIXlt values are formatted via
[`format()`](https://rdrr.io/r/base/format.html) so that a `Date` column
emits ISO date strings ("2024-01-02") rather than the default scale-tick
labels ("Jan 02"). All other types use
[`as.character()`](https://rdrr.io/r/base/character.html). Mirrors
`Ggplot2CandlestickProcessor$format_x_value()` so candle and bar layers
from the same Date column align string-wise.

#### Usage

    Ggplot2BarLayerProcessor$format_x_value(x)

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$panel_x_is_discrete()`

Does this panel draw x on a discrete scale?

Only a discrete scale numbers its built positions 1..n, which is what
makes indexing the break labels with them legitimate.

#### Usage

    Ggplot2BarLayerProcessor$panel_x_is_discrete(panel_params, x_pos, panel_labels)

#### Arguments

- `panel_params`:

  This panel's entry from `built$layout$panel_params`

- `x_pos`:

  Built x positions for this panel

- `panel_labels`:

  This panel's x break labels, or NULL

#### Returns

TRUE for a discrete x scale

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$map_discrete_x()`

Label discrete built positions with this panel's breaks.

#### Usage

    Ggplot2BarLayerProcessor$map_discrete_x(x_pos, panel_labels)

#### Arguments

- `x_pos`:

  Built x positions for this panel

- `panel_labels`:

  This panel's x break labels, or NULL

#### Returns

Character vector of x labels

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$map_continuous_x()`

Recover user-facing x values for a non-discrete scale.

Built positions on a continuous, Date or datetime scale already are the
values, but a Date arrives as a day count. Matching them back to the
mapped column restores the original typing so `format_x_value()` can
emit "2024-01-02" rather than "19724". Mirrors the same recovery in
`Ggplot2LineLayerProcessor`.

#### Usage

    Ggplot2BarLayerProcessor$map_continuous_x(x_pos, plot, layer_index)

#### Arguments

- `x_pos`:

  Built x positions for this panel

- `plot`:

  The ggplot object

- `layer_index`:

  Index of this layer within the plot

#### Returns

Character vector of x labels

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$generate_selectors()`

#### Usage

    Ggplot2BarLayerProcessor$generate_selectors(
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

------------------------------------------------------------------------

### `Ggplot2BarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2BarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
