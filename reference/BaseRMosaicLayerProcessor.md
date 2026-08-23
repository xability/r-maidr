# Base R Mosaic Plot Layer Processor

Processes Base R
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) layers
– a two-way contingency table drawn as tiles, where a column's **width**
encodes that category's share of all observations and a tile's height
its conditional proportion within the column.

Read as a `mosaic` layer, which exists for exactly this shape. Read as a
`stacked_bar` it would lose the width entirely, and the width is half
the table: the conditional proportions would arrive without the group
sizes they were computed from, so a category of six observations and one
of six hundred would read identically.

Nothing here is inferred from the drawing.
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
handed the table itself, so the recorded call carries every number the
trace wants – the counts, the margins they imply, and the level names
from [`dimnames()`](https://rdrr.io/r/base/dimnames.html).

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRMosaicLayerProcessor`

## Methods

### Public methods

- [`BaseRMosaicLayerProcessor$process()`](#method-BaseRMosaicLayerProcessor-process)

- [`BaseRMosaicLayerProcessor$needs_reordering()`](#method-BaseRMosaicLayerProcessor-needs_reordering)

- [`BaseRMosaicLayerProcessor$extract_data()`](#method-BaseRMosaicLayerProcessor-extract_data)

- [`BaseRMosaicLayerProcessor$recorded_table()`](#method-BaseRMosaicLayerProcessor-recorded_table)

- [`BaseRMosaicLayerProcessor$extract_axis_titles()`](#method-BaseRMosaicLayerProcessor-extract_axis_titles)

- [`BaseRMosaicLayerProcessor$extract_main_title()`](#method-BaseRMosaicLayerProcessor-extract_main_title)

- [`BaseRMosaicLayerProcessor$generate_selectors()`](#method-BaseRMosaicLayerProcessor-generate_selectors)

- [`BaseRMosaicLayerProcessor$clone()`](#method-BaseRMosaicLayerProcessor-clone)

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

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$process()`

Process the mosaic layer.

#### Usage

    BaseRMosaicLayerProcessor$process(
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

  Unused for Base R (kept for interface compatibility)

- `layout`:

  Unused for Base R (kept for interface compatibility)

- `built`:

  Unused for Base R (kept for interface compatibility)

- `gt`:

  Gtable object used for selector generation (optional)

- `grob_id`:

  Unused for Base R

- `panel_id`:

  Unused for Base R

- `panel_ctx`:

  Unused for Base R

- `layer_info`:

  Information about the recorded plot call

#### Returns

List with data, selectors, type, title and axes

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$needs_reordering()`

#### Usage

    BaseRMosaicLayerProcessor$needs_reordering()

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$extract_data()`

Read the table out of the recorded
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call.

The emitted shape is the segmented one the stacked bar processor already
produces – `data[[fill]][[category]]` – because the core builds
`MosaicTrace` on `SegmentedTrace` and navigates it category-then-series
exactly as a stack.
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) splits
along the first dimension into columns and each column along the second,
so the first dimension is the category and the second the fill.

Each cell carries four numbers rather than one:

- `y`, the cell's conditional proportion within its column – the tile's
  height, and what a stack's value would be;

- `width`, the column's share of all observations – carried on every
  cell of the column, because the grammar's unit is the point and a flat
  list has nowhere else to put it;

- `count`, the cell's own count. A mosaic is drawn *from* counts and
  they are the numbers a reader would quote back;

- `z`, the fill level's name.

A column that observed nothing has no conditional proportions to report
– dividing would give `NaN` for every cell – so its cells carry a
proportion of 0 alongside their true count of 0. That is what the chart
draws: a column of zero width and no tiles.

#### Usage

    BaseRMosaicLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Nested list of points, empty when there is no table to read

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$recorded_table()`

The two-way table the call was handed, when it is one.

Only a two-dimensional table is read.
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
accepts three and more, splitting recursively, and a `mosaic` layer has
one category axis and one fill – so a deeper table has nowhere to put
its later dimensions and is declined rather than flattened into a
cross-classification the chart does not claim.

#### Usage

    BaseRMosaicLayerProcessor$recorded_table(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

A 2-D table, or NULL

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$extract_axis_titles()`

Name the axes from the table's own dimension names.

[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) labels
its axes with `names(dimnames(x))` unless the author overrides them –
"Hair" and "Eye" for `HairEyeColor[, , 1]` – so those are the two words
a reader should be given for the two dimensions.

Which grammar axis each lands on is not the chart's own arrangement. The
second dimension is what
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
up the y axis, but a segmented layer's `y` holds the *magnitude* and its
`z` the fill, so the second dimension is named on `z` and `y` says what
its numbers are. `ylab` follows the dimension it names rather than the
axis it shares a letter with, for the same reason.

#### Usage

    BaseRMosaicLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$extract_main_title()`

The title the call was given, if any.

[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
a default `main` of its own from the deparsed data expression, but the
recorded call carries only what the author passed, and a title invented
from a variable name is not something a reader can act on.

#### Usage

    BaseRMosaicLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Character scalar, empty when the author wrote no title

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$generate_selectors()`

Address the tiles the chart drew.

Measured on a rendered `mosaicplot(HairEyeColor[, , 1])`: gridGraphics
draws one `-polygon-N` grob per cell and nothing else as a polygon – 16
grobs for a 4x4 table, with no frame among them. Their geometry says the
order: `polygon-1` to `-4` share the leftmost column's x extent, `-5` to
`-8` the next one's, and within a column the grob number runs down the
fill levels in the table's own order. So the tile for row `f` of column
`c` is the `(c - 1) * fills + f`th grob.

The grobs are *found* rather than named by formula, and a short list is
declined: a guessed id resolves to nothing at best and to another
panel's tiles at worst, and a mosaic with no highlight still reads – the
outcome \#145 established for a layer with nothing to point at.

#### Usage

    BaseRMosaicLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

- `gt`:

  Gtable object to search

#### Returns

List of selectors, one per cell, or empty when unresolvable

------------------------------------------------------------------------

### `BaseRMosaicLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRMosaicLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
