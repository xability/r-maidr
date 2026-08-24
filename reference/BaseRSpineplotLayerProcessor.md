# Base R Spine Plot Layer Processor

Reads [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
as the two-way contingency table it draws.

A spine plot is a mosaic of one categorical axis against another: one
column per level of `x`, its **width** that level's share of all
observations, split vertically by `y`'s conditional proportions inside
it. That is the shape `BaseRMosaicLayerProcessor` was written for in
\#247 – "the column widths encode data too" – so a spine plot is read as
a `mosaic` layer, and this class changes only the two things that
differ.

**Where the table comes from.**
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
handed its table, so the recorded call carries it.
[`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
handed the two variables and builds the table itself, and it has **no
`plot` argument** to be asked for the table without drawing –
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has one,
[`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) does
not. But it *returns* what it drew:


    spineplot(table(f, g))
    #       g
    # f      no yes
    #   low  11  12
    #   mid   7  14
    #   high 12   4

so the call is replayed on a throwaway device and the return value
taken.
[`graphics::spineplot`](https://rdrr.io/r/graphics/spineplot.html) by
the qualified name, not the bare one: maidr patches the name on the
search path, and the bare call would record the replay as a second
chart. Reproducing the binning by hand instead would be a re-derivation
– `spineplot` cuts a numeric `x` by its own rule – and the point of
every reading in this package is that the library is asked rather than
imitated.

**Where the tiles are.**
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
one `polygon` grob per cell.
[`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
**one `rect` grob for the whole panel**, and gridSVG exports it as one
`<rect>` element per tile. Measured on a 3x2 table:


    graphics-plot-1-rect-1.1.1   x  59.04   w 152.86   h 118.71
    graphics-plot-1-rect-1.1.2   x  59.04   w 152.86   h 108.81
    graphics-plot-1-rect-1.1.3   x 219.88   w 139.57   h 151.68
    graphics-plot-1-rect-1.1.4   x 219.88   w 139.57   h  75.84
    graphics-plot-1-rect-1.1.5   x 367.42   w 106.34   h  56.88
    graphics-plot-1-rect-1.1.6   x 367.42   w 106.34   h 170.64

Six elements for six cells, sharing an x within a column, and the widths
152.86 : 139.57 : 106.34 in the marginals' own ratio 23 : 21 : 16. The
order is column-major, and **within a column the last fill level is
drawn first**: the heights pair 118.71 : 108.81 with 12 : 11, which is
`yes` above `no`. That is the opposite of the mosaic's ascending order,
which is why the index is computed here rather than inherited.

**A zero cell still draws.** The hazard this shape invites is the one
xability/maidr#1002 found elsewhere: a count of zero skipped rather than
drawn, shifting every later tile's index by one. Measured on a table
with a genuine zero in it, `spineplot` draws the tile anyway with
`height="0"`, so the positional pairing holds. There is a test for
exactly that.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRMosaicLayerProcessor`](https://r.maidr.ai/reference/BaseRMosaicLayerProcessor.md)
-\> `BaseRSpineplotLayerProcessor`

## Methods

### Public methods

- [`BaseRSpineplotLayerProcessor$recorded_table()`](#method-BaseRSpineplotLayerProcessor-recorded_table)

- [`BaseRSpineplotLayerProcessor$generate_selectors()`](#method-BaseRSpineplotLayerProcessor-generate_selectors)

- [`BaseRSpineplotLayerProcessor$clone()`](#method-BaseRSpineplotLayerProcessor-clone)

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
- [`BaseRMosaicLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRMosaicLayerProcessor.html#method-extract_axis_titles)
- [`BaseRMosaicLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRMosaicLayerProcessor.html#method-extract_data)
- [`BaseRMosaicLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRMosaicLayerProcessor.html#method-extract_main_title)
- [`BaseRMosaicLayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/BaseRMosaicLayerProcessor.html#method-needs_reordering)
- [`BaseRMosaicLayerProcessor$process()`](https://r.maidr.ai/reference/BaseRMosaicLayerProcessor.html#method-process)

------------------------------------------------------------------------

### `BaseRSpineplotLayerProcessor$recorded_table()`

The table
[`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) drew,
by replaying the call

Memoised, because `process()` asks for it three times – once for the
data, once for the axis names and once for the selectors – and each ask
would otherwise open a device and draw the chart again.

#### Usage

    BaseRSpineplotLayerProcessor$recorded_table(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

A 2-D table, or NULL when the call cannot be replayed

------------------------------------------------------------------------

### `BaseRSpineplotLayerProcessor$generate_selectors()`

Address the tile each cell was drawn into

One `rect` grob holds the whole panel, so the tiles are its sub-elements
rather than grobs of their own and are addressed by their exported ids.
The grob is *found* rather than named by formula, and a panel that does
not hold exactly one is declined: a guessed id resolves to nothing at
best and to another panel's tiles at worst, and a spine plot with no
highlight still reads (#145).

The index runs column-major with the fill levels **descending** inside a
column, which is the order measured off the drawing and recorded in the
class note. The emitted list is in the payload's own order – all
categories of the first fill, then the second – so the two line up.

#### Usage

    BaseRSpineplotLayerProcessor$generate_selectors(layer_info, gt = NULL)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

- `gt`:

  Gtable object to search

#### Returns

List of selectors, one per cell, or empty when unresolvable

------------------------------------------------------------------------

### `BaseRSpineplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRSpineplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
