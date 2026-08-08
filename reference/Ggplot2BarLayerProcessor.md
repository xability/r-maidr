# Bar Layer Processor

Bar Layer Processor

Bar Layer Processor

## Details

Processes bar plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2BarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2BarLayerProcessor$process()`](#method-Ggplot2BarLayerProcessor-process)

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

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2BarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `needs_reordering()`

#### Usage

    Ggplot2BarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `reorder_layer_data()`

#### Usage

    Ggplot2BarLayerProcessor$reorder_layer_data(data, plot)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2BarLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL,
      panel_id = NULL
    )

------------------------------------------------------------------------

### Method `format_x_value()`

Format an x-axis value as character.

Date / POSIXct / POSIXlt values are formatted via \`format()\` so that a
\`Date\` column emits ISO date strings ("2024-01-02") rather than the
default scale-tick labels ("Jan 02"). All other types use
\`as.character()\`. Mirrors
\`Ggplot2CandlestickProcessor\$format_x_value()\` so candle and bar
layers from the same Date column align string-wise.

#### Usage

    Ggplot2BarLayerProcessor$format_x_value(x)

------------------------------------------------------------------------

### Method `panel_x_is_discrete()`

Does this panel draw x on a discrete scale?

Only a discrete scale numbers its built positions 1..n, which is what
makes indexing the break labels with them legitimate.

#### Usage

    Ggplot2BarLayerProcessor$panel_x_is_discrete(panel_params, x_pos, panel_labels)

#### Arguments

- `panel_params`:

  This panel's entry from \`built\$layout\$panel_params\`

- `x_pos`:

  Built x positions for this panel

- `panel_labels`:

  This panel's x break labels, or NULL

#### Returns

TRUE for a discrete x scale

------------------------------------------------------------------------

### Method `map_discrete_x()`

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

### Method `map_continuous_x()`

Recover user-facing x values for a non-discrete scale.

Built positions on a continuous, Date or datetime scale already are the
values, but a Date arrives as a day count. Matching them back to the
mapped column restores the original typing so \`format_x_value()\` can
emit "2024-01-02" rather than "19724". Mirrors the same recovery in
\`Ggplot2LineLayerProcessor\`.

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

### Method `generate_selectors()`

#### Usage

    Ggplot2BarLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2BarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
