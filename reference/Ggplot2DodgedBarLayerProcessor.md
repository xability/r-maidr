# Dodged Bar Layer Processor

Processes dodged bar plot layers with complete logic included

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2DodgedBarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2DodgedBarLayerProcessor$process()`](#method-Ggplot2DodgedBarLayerProcessor-process)

- [`Ggplot2DodgedBarLayerProcessor$needs_reordering()`](#method-Ggplot2DodgedBarLayerProcessor-needs_reordering)

- [`Ggplot2DodgedBarLayerProcessor$resolve_aes_values()`](#method-Ggplot2DodgedBarLayerProcessor-resolve_aes_values)

- [`Ggplot2DodgedBarLayerProcessor$reorder_layer_data()`](#method-Ggplot2DodgedBarLayerProcessor-reorder_layer_data)

- [`Ggplot2DodgedBarLayerProcessor$extract_data()`](#method-Ggplot2DodgedBarLayerProcessor-extract_data)

- [`Ggplot2DodgedBarLayerProcessor$generate_selectors()`](#method-Ggplot2DodgedBarLayerProcessor-generate_selectors)

- [`Ggplot2DodgedBarLayerProcessor$clone()`](#method-Ggplot2DodgedBarLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### `Ggplot2DodgedBarLayerProcessor$process()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$process(
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

### `Ggplot2DodgedBarLayerProcessor$needs_reordering()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `Ggplot2DodgedBarLayerProcessor$resolve_aes_values()`

Resolve this layer's x/y/fill aesthetics to VALUES.
[`rlang::as_label()`](https://rlang.r-lib.org/reference/as_label.html)
produces a display string, which doubles as a column name only for
bare-column mappings. Evaluating the quosure against the data also
covers expression aesthetics such as `aes(fill = factor(cyl))`, which
are idiomatic ggplot2 and which the column-name treatment turned into
`data[["factor(cyl)"]]`, i.e. NULL.

#### Usage

    Ggplot2DodgedBarLayerProcessor$resolve_aes_values(plot, data)

#### Arguments

- `plot`:

  A ggplot2 object

- `data`:

  Data frame the aesthetics are evaluated against

#### Returns

List with `x`, `y` and `fill` vectors (any may be NULL)

------------------------------------------------------------------------

### `Ggplot2DodgedBarLayerProcessor$reorder_layer_data()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

------------------------------------------------------------------------

### `Ggplot2DodgedBarLayerProcessor$extract_data()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$extract_data(
      plot,
      built = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

------------------------------------------------------------------------

### `Ggplot2DodgedBarLayerProcessor$generate_selectors()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

------------------------------------------------------------------------

### `Ggplot2DodgedBarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2DodgedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
