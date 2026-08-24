# Base R Filled Contour Layer Processor

Reads a base R
[`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
call as the contour it draws.

`filled.contour` draws the same level curves
[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) does and
fills the bands between them, so it is read the same way: one curve per
level, from
[`grDevices::contourLines()`](https://rdrr.io/r/grDevices/contourLines.html),
which is the computation the drawing itself runs. One chart with two
spellings gets one reading.

Two things differ from
[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md), and only
two:

**The level default.** `contour.default` takes `nlevels = 10` and
`filled.contour` takes `nlevels = 20`, and the number decides the whole
announced set through `pretty(zlim, nlevels)`. Everything else about
resolving the call – the `(x, y, z, ...)` slots, the
`if (missing(z)) z <- x` fallback, the `list(x =, y =, z =)` unpacking,
the `zlim` default – is identical in both, so this class overrides the
number and inherits the rest.

**The chart cannot be highlighted, and the inherited code already knows
it.** [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
writes one `lines` grob per curve, which is what `generate_selectors()`
pairs against. `filled.contour` writes one `polygon` grob for the entire
field, and gridSVG exports it as a flat run of pieces. Measured on a 6x5
grid drawn at the 17 default levels:

    grobs written    graphics-plot-2-filled-contour-1   (one)
    SVG polygons     graphics-plot-2-filled-contour-1.1.1 .. .1.160
    curves announced 40

160 pieces against 40 curves, and against 17 levels: the polygons are
the grid's cells cut by the level crossings, not the bands and not the
curves. Nothing pairs, so nothing is emitted – the inherited
`generate_selectors()` finds no `-contour-N-N` grob, its count check
fails, and it withholds the list, which is the same answer it gives a
[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) whose
grobs and curves disagree. A layer with no selectors is announced,
sonified and navigated; it is the visual highlight alone that is
missing, and that is the established degradation here (#89) rather than
a reason to ship a picture.

Note also that the field is drawn in the **second** plot region: the
call lays out a colour key as `graphics-plot-1` and the field as
`graphics-plot-2`. Nothing here depends on that, because nothing here
addresses a grob, but a later attempt to highlight this chart will.

py-maidr declines the equivalent call. Its reason – recorded in
`maidr/patch/contour.py` – is that `contourf` hands back the filled
paths and "an outline of one runs along two different level curves",
which is a statement about deriving curves from what was drawn. It does
not apply here: R hands over
[`contourLines()`](https://rdrr.io/r/grDevices/contourLines.html), so
the curves announced are the level curves themselves rather than an
inference from the fill, and every one of them is on the page as the
boundary between two bands.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`BaseRContourLayerProcessor`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.md)
-\> `BaseRFilledContourLayerProcessor`

## Methods

### Public methods

- [`BaseRFilledContourLayerProcessor$default_nlevels()`](#method-BaseRFilledContourLayerProcessor-default_nlevels)

- [`BaseRFilledContourLayerProcessor$clone()`](#method-BaseRFilledContourLayerProcessor-clone)

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
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$other_geom_grob_prefixes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-other_geom_grob_prefixes)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$resolve_panel_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-resolve_panel_index)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)
- [`BaseRContourLayerProcessor$contour_grid()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-contour_grid)
- [`BaseRContourLayerProcessor$extract_axis_titles()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-extract_axis_titles)
- [`BaseRContourLayerProcessor$extract_data()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-extract_data)
- [`BaseRContourLayerProcessor$extract_main_title()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-extract_main_title)
- [`BaseRContourLayerProcessor$find_contour_grobs()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-find_contour_grobs)
- [`BaseRContourLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-generate_selectors)
- [`BaseRContourLayerProcessor$process()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-process)
- [`BaseRContourLayerProcessor$read_curves()`](https://r.maidr.ai/reference/BaseRContourLayerProcessor.html#method-read_curves)

------------------------------------------------------------------------

### `BaseRFilledContourLayerProcessor$default_nlevels()`

How many levels
[`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
defaults to

Twice [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s,
and the only number that separates the two.

#### Usage

    BaseRFilledContourLayerProcessor$default_nlevels()

#### Returns

20

------------------------------------------------------------------------

### `BaseRFilledContourLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRFilledContourLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
