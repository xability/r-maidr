# Base R Contour Layer Processor

Reads a base R
[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) call as
the contour it draws.

[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) had no
processor. `base_r_adapter` mapped the call to the type `"contour"` and
the factory fell through to the generic processor, so the layer shipped
typed `"unknown"` – and the core's trace factory ends its dispatch with
`throw new Error("Invalid trace type: …")`, so the figure bound
interactively and then failed to construct. \#214 stopped that by typing
the call `"unknown"` at the adapter, which degrades to a static image;
this replaces the picture with the reading (#218).

The curves come from
[`grDevices::contourLines()`](https://rdrr.io/r/grDevices/contourLines.html),
which is the same computation
[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) does and
takes the same defaults, so nothing here is a guess about what was
drawn:


    contour.default(x = seq(0, 1, length.out = nrow(z)),
                    y = seq(0, 1, length.out = ncol(z)),
                    z, nlevels = 10, levels = pretty(zlim, nlevels),
                    zlim = range(z, finite = TRUE))

The payload matches `ggplot2_contour_layer_processor.R` exactly – a list
of curves, each a list of `{x, y, level}` – so the two adapters describe
one chart the same way.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRContourLayerProcessor`

## Methods

### Public methods

- [`BaseRContourLayerProcessor$process()`](#method-BaseRContourLayerProcessor-process)

- [`BaseRContourLayerProcessor$read_curves()`](#method-BaseRContourLayerProcessor-read_curves)

- [`BaseRContourLayerProcessor$extract_data()`](#method-BaseRContourLayerProcessor-extract_data)

- [`BaseRContourLayerProcessor$contour_grid()`](#method-BaseRContourLayerProcessor-contour_grid)

- [`BaseRContourLayerProcessor$extract_axis_titles()`](#method-BaseRContourLayerProcessor-extract_axis_titles)

- [`BaseRContourLayerProcessor$extract_main_title()`](#method-BaseRContourLayerProcessor-extract_main_title)

- [`BaseRContourLayerProcessor$generate_selectors()`](#method-BaseRContourLayerProcessor-generate_selectors)

- [`BaseRContourLayerProcessor$find_contour_grobs()`](#method-BaseRContourLayerProcessor-find_contour_grobs)

- [`BaseRContourLayerProcessor$clone()`](#method-BaseRContourLayerProcessor-clone)

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

### `BaseRContourLayerProcessor$process()`

Build the layer

#### Usage

    BaseRContourLayerProcessor$process(
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

### `BaseRContourLayerProcessor$read_curves()`

Read the drawn curves off the recorded call

Hands back which curves were kept as well as the curves themselves.
gridGraphics draws from the same
[`contourLines()`](https://rdrr.io/r/grDevices/contourLines.html)
output, so it writes one grob per curve *before* any filtering here –
and comparing a filtered count against an unfiltered one would make the
two disagree, which `generate_selectors` answers by withholding the
whole layer's highlighting. Keeping the indices lets each announced
curve take the grob that drew it, whatever was dropped.

#### Usage

    BaseRContourLayerProcessor$read_curves(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

`data` (curves of `{x, y, level}`), `kept` (their indices among what
[`contourLines()`](https://rdrr.io/r/grDevices/contourLines.html)
returned) and `total` (how many that was)

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$extract_data()`

The curves alone, for callers that want only the payload

#### Usage

    BaseRContourLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

A list of curves, each a list of `{x, y, level}` points

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$contour_grid()`

The grid and levels the call drew, or NULL when it drew none

Resolved the way `contour.default` resolves it, rather than by a rule of
our own. Its arguments are `(x, y, z, ...)`; a named argument claims its
slot and the unnamed ones fill what is left, in order. Then, and only
then:


      if (missing(z) && !missing(x) && !is.list(x)) { z <- x; x <- NULL }
      

which is what makes `contour(m)` a contour *of* `m` rather than a chart
with `m` on the x axis.

Reproducing that matters because the wrapper records a partially named
call: measured, `contour(c(10, 20, 30), c(100, 200, 300), z)` arrives as
one unnamed argument plus `y =` and `z =`. A rule that looked for the
matrix and took the unnamed arguments *before* it found `z` already
named, never looked at the unnamed one, and announced the caller's grid
on the 0-1 default – every coordinate wrong, and nothing raised.

#### Usage

    BaseRContourLayerProcessor$contour_grid(args)

#### Arguments

- `args`:

  The recorded call's arguments

#### Returns

A list of `x`, `y`, `z` and `levels`, or NULL

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$extract_axis_titles()`

Name the two axes

Only x and y. The level is not an axis here: it travels on every point
of the curve it belongs to, which is where the frontend's contour trace
reads it from – the same choice `ggplot2_contour_layer_processor` makes,
so the two adapters describe one chart alike.

No default label.
[`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) prints
the deparsed argument when the caller names nothing, and those names are
gone by the time the wrapper has recorded evaluated values – so a
guessed noun would be worse than none, and the axis is left to the
renderer's generic.

#### Usage

    BaseRContourLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

An axes payload

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$extract_main_title()`

The chart's own title, where the call gave one

#### Usage

    BaseRContourLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  The recorded call

#### Returns

The title, or an empty string

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$generate_selectors()`

Address each curve by the element that drew it

gridGraphics writes one `lines` grob per curve, named
`graphics-plot-<group>-contour-<i>-<i>`, in the order
[`contourLines()`](https://rdrr.io/r/grDevices/contourLines.html)
returns them – checked vertex count by vertex count, not assumed. A
`lines` grob renders as a `<polyline>`.

Withheld entirely when the count does not match what was announced. The
frontend drops a layer whose selector list disagrees with its series
count, and a partial list would hand a curve its neighbour's element –
the defect \#145 and \#204 are both about.

#### Usage

    BaseRContourLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      kept = integer(0),
      total = 0
    )

#### Arguments

- `layer_info`:

  The recorded call

- `gt`:

  The grob tree

- `kept`:

  Which of the drawn curves were announced

- `total`:

  How many curves were drawn

#### Returns

A list of CSS selectors, one per announced curve

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$find_contour_grobs()`

Every contour grob this layer drew

#### Usage

    BaseRContourLayerProcessor$find_contour_grobs(grob, group_index)

#### Arguments

- `grob`:

  The grob tree

- `group_index`:

  Which plot on the device

#### Returns

A character vector of grob names

------------------------------------------------------------------------

### `BaseRContourLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRContourLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
