# Dodged Bar Layer Processor

Dodged Bar Layer Processor

Dodged Bar Layer Processor

## Details

Processes dodged bar plot layers with complete logic included

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2DodgedBarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2DodgedBarLayerProcessor$process()`](#method-Ggplot2DodgedBarLayerProcessor-process)

- [`Ggplot2DodgedBarLayerProcessor$needs_reordering()`](#method-Ggplot2DodgedBarLayerProcessor-needs_reordering)

- [`Ggplot2DodgedBarLayerProcessor$resolve_aes_values()`](#method-Ggplot2DodgedBarLayerProcessor-resolve_aes_values)

- [`Ggplot2DodgedBarLayerProcessor$discrete_level_order()`](#method-Ggplot2DodgedBarLayerProcessor-discrete_level_order)

- [`Ggplot2DodgedBarLayerProcessor$reorder_layer_data()`](#method-Ggplot2DodgedBarLayerProcessor-reorder_layer_data)

- [`Ggplot2DodgedBarLayerProcessor$extract_data()`](#method-Ggplot2DodgedBarLayerProcessor-extract_data)

- [`Ggplot2DodgedBarLayerProcessor$generate_selectors()`](#method-Ggplot2DodgedBarLayerProcessor-generate_selectors)

- [`Ggplot2DodgedBarLayerProcessor$clone()`](#method-Ggplot2DodgedBarLayerProcessor-clone)

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

    Ggplot2DodgedBarLayerProcessor$process(
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

    Ggplot2DodgedBarLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### Method `resolve_aes_values()`

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

### Method `discrete_level_order()`

Order the distinct values of an aesthetic the way ggplot2 lays them out,
so the emitted columns line up with the drawn ones. A factor follows its
own level order, minus the levels nothing was drawn for; anything else
sorts in its own type's order. Sorting the values AS TEXT, which is what
this used to do, reordered the columns twice over: against a factor
whose levels are not alphabetical, and against a number, where it puts
10 before 2.

#### Usage

    Ggplot2DodgedBarLayerProcessor$discrete_level_order(values)

#### Arguments

- `values`:

  A vector of aesthetic values

#### Returns

Character vector of the observed levels, in drawn order

------------------------------------------------------------------------

### Method `reorder_layer_data()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$reorder_layer_data(data, plot)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$extract_data(
      plot,
      built = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2DodgedBarLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL
    )

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2DodgedBarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
