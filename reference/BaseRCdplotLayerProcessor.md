# Base R Conditional Density Plot Layer Processor

Reads [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) as
the 100% stacked area chart it draws.

A conditional density plot shows, for each value of a numeric `x`, how
the levels of a factor `y` divide up: the bands are stacked, they fill
the whole height, and their shares sum to 1 at every x. That is a
normalized stacked area, which `Ggplot2AreaLayerProcessor` already emits
for `position = "fill"`, so a
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is read as
`stacked_normalized_area` and the two adapters describe one chart the
same way – each series a list of `{x, y, z}` where `y` is the band's own
share and `z` names the level, and one selector per band.

Before this,
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) had no
branch in `detect_layer_type()`, so the switch fell through to
`"unknown"` and the chart degraded to a static image (#216, \#251).

### Where the curves come from

[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has a
`plot` argument, so it can be asked for what it drew without drawing it
again. It returns the **boundaries** between the bands: `nlevels(y) - 1`
functions, each [`approxfun()`](https://rdrr.io/r/stats/approxfun.html)
over the density grid, named for the level *below* the boundary.


    rval <- cdplot(x, y, plot = FALSE)
    names(rval)          # "c" "b"   for a factor with levels a, b, c
    rval[[1]](50)        # the cumulative share at x = 50

Stacking them the way
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) does –
`rbind(0, boundaries, 1)`, band `i` running from row `i` to row `i + 1`
– gives the shares back. Measured over three hundred random charts,
every column's shares sum to 1 and no band comes out negative, so the
boundaries do not cross in the drawn range.

[`graphics::cdplot`](https://rdrr.io/r/graphics/cdplot.html) by the
qualified name, not the bare one: maidr patches the name on the search
path, and a bare call would record the replay as a second chart. The
same line `BaseRSpineplotLayerProcessor` draws.

### Which x values were drawn

The returned functions interpolate over the density grid, which
[`stats::density()`](https://rdrr.io/r/stats/density.html) pads past the
data by three bandwidths.
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) throws
that padding away before drawing:


    y1 <- y1[, which(x1 >= min(x) & x1 <= max(x))]
    x1 <- x1[x1 >= min(x) & x1 <= max(x)]

so the announced grid is trimmed the same way – 372 of the 512 points on
a measured chart. Announcing the untrimmed grid would put readings
either side of the data at x values the chart has no marks at.

The grid itself is read off the first returned function rather than
recomputed: [`approxfun()`](https://rdrr.io/r/stats/approxfun.html)
keeps its knots, and `environment(f)$x` is the grid
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) built.
Recomputing [`density()`](https://rdrr.io/r/stats/density.html) here
would have to guess `bw`, `n`, `from`, `to` and `weights` back out of
the recorded call, and a guess that differed by one point would shift
every reading.

### What the replay proves

A [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) that
returned rather than stopping has already established most of what a
reader here would otherwise have to check, because
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) checks it
first and stops. Each was measured:

- `y` is a factor – "dependent variable should be a factor";

- `x` is finite –
  [`stats::density()`](https://rdrr.io/r/stats/density.html) stops on a
  missing or infinite value;

- a formula names exactly two variables – "'formula' should specify
  exactly two variables";

- the grid overlaps the data – a `from`/`to` that put it elsewhere stops
  with "need at least two non-NA values to interpolate";

- the factor has at least two levels – one stops with "subscript out of
  bounds".

The NULL checks that remain below are therefore not checking any of
that. They are there so that a shape none of the above rules out cannot
*throw* out of the pipeline, where declining to read leaves the static
image the figure produces today. Where a check would only repeat one
another check already makes, it is not written twice.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRCdplotLayerProcessor`

## Methods

### Public methods

- [`BaseRCdplotLayerProcessor$process()`](#method-BaseRCdplotLayerProcessor-process)

- [`BaseRCdplotLayerProcessor$extract_data()`](#method-BaseRCdplotLayerProcessor-extract_data)

- [`BaseRCdplotLayerProcessor$drawn_bands()`](#method-BaseRCdplotLayerProcessor-drawn_bands)

- [`BaseRCdplotLayerProcessor$replay()`](#method-BaseRCdplotLayerProcessor-replay)

- [`BaseRCdplotLayerProcessor$drawn_grid()`](#method-BaseRCdplotLayerProcessor-drawn_grid)

- [`BaseRCdplotLayerProcessor$band_levels()`](#method-BaseRCdplotLayerProcessor-band_levels)

- [`BaseRCdplotLayerProcessor$predictor()`](#method-BaseRCdplotLayerProcessor-predictor)

- [`BaseRCdplotLayerProcessor$response()`](#method-BaseRCdplotLayerProcessor-response)

- [`BaseRCdplotLayerProcessor$variables()`](#method-BaseRCdplotLayerProcessor-variables)

- [`BaseRCdplotLayerProcessor$default_variables()`](#method-BaseRCdplotLayerProcessor-default_variables)

- [`BaseRCdplotLayerProcessor$formula_variables()`](#method-BaseRCdplotLayerProcessor-formula_variables)

- [`BaseRCdplotLayerProcessor$extract_axis_titles()`](#method-BaseRCdplotLayerProcessor-extract_axis_titles)

- [`BaseRCdplotLayerProcessor$extract_main_title()`](#method-BaseRCdplotLayerProcessor-extract_main_title)

- [`BaseRCdplotLayerProcessor$generate_selectors()`](#method-BaseRCdplotLayerProcessor-generate_selectors)

- [`BaseRCdplotLayerProcessor$clone()`](#method-BaseRCdplotLayerProcessor-clone)

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

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$process()`

Build the layer

#### Usage

    BaseRCdplotLayerProcessor$process(
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

- `plot, layout, built, gt, grob_id, panel_id, panel_ctx`:

  Pipeline arguments

- `layer_info`:

  The recorded call

#### Returns

List with data, selectors, type, title and axes

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$extract_data()`

One series per band, bottom to top

Bottom to top because that is the order
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws its
polygons in, and the selector list is positional against those polygons.

#### Usage

    BaseRCdplotLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

A list of series, each a list of `{x, y, z}` points

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$drawn_bands()`

The grid, the band names and their shares, or NULL

NULL rather than an empty list when the call cannot be read, so every
caller degrades the same way: no data, no selectors, and the figure
falls back to the static image it produces today.

#### Usage

    BaseRCdplotLayerProcessor$drawn_bands(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

A list of `x`, `levels` and `shares` (a bands-by-points matrix), or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$replay()`

Ask [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) what
it drew, without drawing it

#### Usage

    BaseRCdplotLayerProcessor$replay(args)

#### Arguments

- `args`:

  The recorded call's arguments

#### Returns

The list of boundary functions, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$drawn_grid()`

The x values the bands were drawn over

#### Usage

    BaseRCdplotLayerProcessor$drawn_grid(boundaries, args)

#### Arguments

- `boundaries`:

  The replayed boundary functions

- `args`:

  The recorded call's arguments

#### Returns

A numeric vector, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$band_levels()`

The band names, bottom to top

[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) names its
boundaries for every level but the topmost, so the one it does not name
is the one level of the response that is left. Derived that way rather
than by reproducing the `ylevels` argument's reordering, which is
[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s to
define.

Declines unless exactly one level is left over. That is the one guard
the step needs, and it does double duty: an `ylevels` naming a strict
subset of the factor's levels leaves two over – measured,
`ylevels = c("a", "b")` on a three-level factor – and unnamed boundaries
would leave every level over. Either way the reading would be missing a
band, and every selector after it would point at its neighbour.

An empty level name is *not* declined. `factor(x, levels = c("b", ""))`
is a level like any other,
[`setdiff()`](https://rdrr.io/r/base/sets.html) matches it like any
other, and the chart draws a band for it – so it is announced with the
empty name the axis shows rather than dropped.

#### Usage

    BaseRCdplotLayerProcessor$band_levels(boundaries, args)

#### Arguments

- `boundaries`:

  The replayed boundary functions

- `args`:

  The recorded call's arguments

#### Returns

A character vector, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$predictor()`

The numeric variable on the x axis

#### Usage

    BaseRCdplotLayerProcessor$predictor(args)

#### Arguments

- `args`:

  The recorded call's arguments

#### Returns

A numeric vector, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$response()`

The factor whose levels the bands are

#### Usage

    BaseRCdplotLayerProcessor$response(args)

#### Arguments

- `args`:

  The recorded call's arguments

#### Returns

A factor, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$variables()`

The two variables the call was given, whichever form it took

[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has two
methods and they name their variables differently: `cdplot(x, y)` and
`cdplot(y ~ x, data)`. The formula method builds a model frame and takes
the response from column one and the predictor from column two, which is
reproduced here because the recorded call carries the formula rather
than the frame.

Memoised. `process()` reaches this three times – through `response()`,
through `predictor()` and again for the axis names – and on the formula
path each ask would rebuild a model frame and re-apply the subset. The
same call `BaseRSpineplotLayerProcessor` makes about its replayed table,
for the same reason. Nothing observable changes, which is why this is
written down rather than left to be rediscovered.

#### Usage

    BaseRCdplotLayerProcessor$variables(args)

#### Arguments

- `args`:

  The recorded call's arguments

#### Returns

A list of `x`, `y` and `names`, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$default_variables()`

The variables of a `cdplot(x, y)` call

#### Usage

    BaseRCdplotLayerProcessor$default_variables(args)

#### Arguments

- `args`:

  The recorded call's arguments

#### Returns

A list of `x`, `y` and `names`, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$formula_variables()`

The variables of a `cdplot(y ~ x, data)` call

`subset` is carried through, because `cdplot.formula` builds its model
frame with it and everything downstream is the subset's: measured on
`cdplot(b ~ a, data = d, subset = a > 45)`, the chart draws over 46.1 to
70.9 while the whole column runs from 25.5. Read without the subset, the
grid would be trimmed to the wider range and a fifth of the announced
points would sit left of the leftmost mark.

#### Usage

    BaseRCdplotLayerProcessor$formula_variables(formula, data, subset = NULL)

#### Arguments

- `formula`:

  The recorded formula

- `data`:

  The recorded data, if any

- `subset`:

  The recorded subset, if any

#### Returns

A list of `x`, `y` and `names`, or NULL

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$extract_axis_titles()`

Name the axes

The band's number is a share of the column, not a position on the drawn
y axis – which carries the level names, and is the *fill* dimension
shown positionally. So `ylab` names `z` and `y` says what its numbers
are, the same split `BaseRMosaicLayerProcessor` makes for the same
reason.

#### Usage

    BaseRCdplotLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

An axes payload

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$extract_main_title()`

The chart's own title, where the call gave one

#### Usage

    BaseRCdplotLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

The title, or an empty string

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$generate_selectors()`

Address each band by the polygon that drew it

[`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes one
`polygon` grob per band, in draw order, which is the bottom-to-top order
the series are in. The frame it draws around the plot is a polygon too,
but gridGraphics names it `-box-1` rather than `-polygon-N`, so the
anchored pattern does not collect it.

Withheld entirely when the counts disagree, for the reason every
processor here gives: a partial list hands a band its neighbour's
element, and a user cannot tell that apart from a correct one.

#### Usage

    BaseRCdplotLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      n_series = 0L
    )

#### Arguments

- `layer_info`:

  The recorded call

- `gt`:

  The grob tree

- `n_series`:

  How many bands the data reports

#### Returns

A list of CSS selectors, one per band

------------------------------------------------------------------------

### `BaseRCdplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRCdplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
