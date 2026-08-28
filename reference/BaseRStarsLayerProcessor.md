# Base R Star Plot Processor

Reads [`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the radar it draws: one closed outline per observation, with a spoke for
each variable.

**It is a multi-line layer.** MAIDR's `radar` trace is navigated as one
– "each spoke a column and each series a row" – so the whole reading is
handing over the matrix with its axes the other way round from the way
[`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes it.
`stars(m)` draws a glyph per **row**, so the rows are the series and the
columns are the spokes, and
[BaseRLineLayerProcessor](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)'s
`extract_multiline_data()` wants series in *columns*. Hence the
transpose, which is the only rearranging here.

**The values are the caller's, not the drawing's.**
[`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) scales
every column to `[0, 1]` before drawing, so the radii on the page are
shares of each column's range rather than the readings themselves.
Announcing those would tell a reader that observation 1 scores 0 on a
variable it merely has the smallest value of. The recorded matrix
carries what the caller measured, and that is what a reader is told.

**It is read without an outline, deliberately.** The marks are there and
the pairing is known – measured by giving each observation its own
`col.stars` and reading every polygon's fill, observation `k` owns
polygons `2k - 1` and `2k`, both filled its colour, plus a `segments-k`
carrying one segment per variable:

    polygon-1  #111199   polygon-2  #111199   segments-1   observation 1
    polygon-3  #229922   polygon-4  #229922   segments-2   observation 2
    ...

What is *not* established is the selector those grobs export to. A
selector is only worth emitting once it has been resolved against a real
export, and a real export cannot be had until the chart stops falling
back to a picture – which is what this reading is for. So the outline is
left for a follow-up that can measure it, rather than guessed from the
grob names. Reading without one is what `gauge` already does upstream
when the marks and the cursor cannot be paired with confidence.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRLineLayerProcessor`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.md)
-\> `BaseRStarsLayerProcessor`

## Methods

### Public methods

- [`BaseRStarsLayerProcessor$process()`](#method-BaseRStarsLayerProcessor-process)

- [`BaseRStarsLayerProcessor$clone()`](#method-BaseRStarsLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$find_layer_polyline_grob()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_polyline_grob)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$is_horizontal_call()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_horizontal_call)
- [`LayerProcessor$layer_polyline_grobs()`](https://r.maidr.ai/reference/LayerProcessor.html#method-layer_polyline_grobs)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)
- [`BaseRLineLayerProcessor$extract_abline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_abline_data)
- [`BaseRLineLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_axis_titles)
- [`BaseRLineLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_data)
- [`BaseRLineLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_main_title)
- [`BaseRLineLayerProcessor$extract_multiline_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_multiline_data)
- [`BaseRLineLayerProcessor$extract_single_line_data()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-extract_single_line_data)
- [`BaseRLineLayerProcessor$find_lines_grobs()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-find_lines_grobs)
- [`BaseRLineLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors)
- [`BaseRLineLayerProcessor$generate_selectors_from_grob()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-generate_selectors_from_grob)
- [`BaseRLineLayerProcessor$get_axis_labels()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_axis_labels)
- [`BaseRLineLayerProcessor$get_x_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_x_range_from_group)
- [`BaseRLineLayerProcessor$get_y_range_from_group()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-get_y_range_from_group)
- [`BaseRLineLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-needs_reordering)
- [`BaseRLineLayerProcessor$selector_grob_type()`](https://r.maidr.ai/reference/BaseRLineLayerProcessor.html#method-selector_grob_type)

------------------------------------------------------------------------

### `BaseRStarsLayerProcessor$process()`

Emit one radar series per observation

#### Usage

    BaseRStarsLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
    )

#### Arguments

- `plot`:

  Unused; present for the processor interface.

- `layout`:

  Unused; present for the processor interface.

- `built`:

  Unused; present for the processor interface.

- `gt`:

  Unused; this reading emits no selectors.

- `grob_id`:

  Unused; present for the processor interface.

- `panel_id`:

  Unused; present for the processor interface.

- `panel_ctx`:

  Unused; present for the processor interface.

- `layer_info`:

  Layer information with the recorded call.

#### Returns

A radar layer, or NULL when nothing was read

------------------------------------------------------------------------

### `BaseRStarsLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRStarsLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
