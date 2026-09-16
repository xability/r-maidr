# Base R Fourfold Display Layer Processor

Processes Base R
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
layers drawn with `std = "ind.max"` or `std = "all.max"` – a 2x2
contingency table drawn as four quarter-circles, one per cell, sized so
the wedge's AREA is proportional to that cell's count.

Read as a `heat` layer, for the same reason
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is: the
drawing is a 2x2 grid of one number per cell, and row-then-column is how
a reader navigates a contingency table. Measured on
`fourfoldplot(as.table(matrix(c(10, 40, 90, 160), 2)), std = "ind.max")`,
the radii and the counts they recover:


    grob                       r        quadrant      r^2 * max(count)  cell
    graphics-plot-1-polygon-1  0.250000 upper LEFT     10               [1, 1]
    graphics-plot-1-polygon-2  0.500000 lower LEFT     40               [2, 1]
    graphics-plot-1-polygon-3  0.750000 upper RIGHT    90               [1, 2]
    graphics-plot-1-polygon-4  1.000000 lower RIGHT   160               [2, 2]

exactly, so `radius / sqrt(count)` is one constant (`0.0790569415` here,
with a relative spread of `1.755e-16`). The table's FIRST dimension runs
vertically and its SECOND horizontally – the transpose of
[`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s
arrangement, and measured from the label grobs, which put
`names(dimnames(x))[1]` at the top and bottom of the drawing and
`names(dimnames(x))[2]` at the left and right.

Nothing is inferred from the drawing.
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
handed the table, so the recorded call carries every number the trace
wants; the grobs are consulted only to decide whether the drawing on the
page is the one the recorded call describes.

### What this deliberately does not do

**It is not a `mosaic` and it is not a `bar`.** A mosaic's tiles tile a
whole and carry proportions of it; these are four independent
quarter-discs separated by `space` (default `0.2`) that tile nothing. A
bar trace would imply a value axis with a zero baseline and one
categorical axis, while measured the radii are on a square-root scale
and the quadrants are laid out in two dimensions.

**The confidence arcs are dropped.** Measured, a `conf.level` draws 8
unfilled arcs (`polygon-5` .. `polygon-12`), arcs `4 + j` and `8 + j`
being the lower and upper bound of cell `c(tab)[j]`. A `heat` layer has
nowhere to carry an interval, so a reader is told the counts and not
that the chart also draws a band around each. Unlike `qqplot`'s band
this does not justify declining: the arcs decorate numbers that ARE
fully carried.

**The odds ratio is never announced.** There is no MAIDR trace for one
scalar. Under `ind.max`/`all.max` a reader gets four counts and can
compute it.

### Where the two gates live, and what the second one cannot do

\#268 asks that a chart whose geometry disagrees LOSE the reading rather
than get a wrong one. That is not achievable here and this does not
pretend it is. Verified against `BaseRPlotOrchestrator$initialize()`,
which runs `detect_layers()`, `resolve_fallback_scope()`,
`create_layer_processors()` and `process_layers()` at lines 122-125: the
picture-versus-chart decision is frozen by line 123, which reads
`private$.layers[[i]]$type` through `unsupported_layer_flags()`. That
field is written only by the two
`private$.layers[[layer_counter]] <- list(type = ...)` assignments at
lines 147 and 169, both from `detect_layer_type()`, and is never
rewritten from a processor result; line 124 does not even build a
processor for a layer already typed `"unknown"` (line 219). A processor
that answered `type = "unknown"` would ship that string with
`has_unsupported_layers()` still FALSE – the \#214 failure
`BaseRProcessorFactory$get_supported_types()` records, where the figure
binds and then fails to construct.

So the split is:

- the **argument** gate is
  [`fourfold_decline_reason()`](https://r.maidr.ai/reference/fourfold_decline_reason.md),
  called from `detect_layer_type()`, and it CAN lose the reading;

- the **geometry** gate is `radii_agree()` below, and it can only return
  [`list()`](https://rdrr.io/r/base/list.html) from
  `generate_selectors()` – the numbers are still announced and nothing
  highlights. That is the shipped pie idiom: "a short list means these
  are not this pie's grobs. Filling the gap with a guessed id would
  silently highlight another panel's wedges."

### What the geometry gate can and cannot see

Measured, and weaker than it looks:

- It is **exactly scale-invariant**. A drawing of `tab * 3`, or of
  `tab * 1e6`, checked against `tab`'s counts gives a relative deviation
  of `1.755e-16` and passes.
  `radius / sqrt(count) == 1 / sqrt(max(tab))` is an identity inside
  `stdize()`, so no table can falsify it and an upstream change to what
  `ind.max` means would go uncaught at runtime. That exposure is carried
  by the live-drawing assertions in `test-base-r-fourfoldplot.R`, the
  same bet the `qqplot` branch makes.

- It **passes for a symmetric table drawn under the default `std`**.
  Measured, `9, 4, 4, 9` under `std = "margins"` gives a relative
  deviation of `0.000e+00`, and so does `7, 7, 7, 7`; algebraically,
  with `n11 = n22 = a` and `n12 = n21 = b`,
  `u / a == (1 - u) / b == 1 / (a + b)`. It recovers off symmetry fast –
  `9, 4, 4, 9.0001` gives `2.778e-06` and fails at `1e-8` – but this is
  why `std` is the first gate and the geometry only the second.

What it does catch is a grob tree that is not this call's: measured,
`fourfoldplot(UCBAdmissions, std = "ind.max")` draws 78 polygons, and an
asymmetric table's `margins` drawing checked against its own counts
gives `7.616e-01`.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`BaseRFourfoldLayerProcessor`

## Methods

### Public methods

- [`BaseRFourfoldLayerProcessor$process()`](#method-BaseRFourfoldLayerProcessor-process)

- [`BaseRFourfoldLayerProcessor$needs_reordering()`](#method-BaseRFourfoldLayerProcessor-needs_reordering)

- [`BaseRFourfoldLayerProcessor$recorded_table()`](#method-BaseRFourfoldLayerProcessor-recorded_table)

- [`BaseRFourfoldLayerProcessor$drawn_dimnames()`](#method-BaseRFourfoldLayerProcessor-drawn_dimnames)

- [`BaseRFourfoldLayerProcessor$extract_data()`](#method-BaseRFourfoldLayerProcessor-extract_data)

- [`BaseRFourfoldLayerProcessor$levels_of()`](#method-BaseRFourfoldLayerProcessor-levels_of)

- [`BaseRFourfoldLayerProcessor$extract_axis_titles()`](#method-BaseRFourfoldLayerProcessor-extract_axis_titles)

- [`BaseRFourfoldLayerProcessor$extract_main_title()`](#method-BaseRFourfoldLayerProcessor-extract_main_title)

- [`BaseRFourfoldLayerProcessor$wedge_names()`](#method-BaseRFourfoldLayerProcessor-wedge_names)

- [`BaseRFourfoldLayerProcessor$radii_agree()`](#method-BaseRFourfoldLayerProcessor-radii_agree)

- [`BaseRFourfoldLayerProcessor$generate_selectors()`](#method-BaseRFourfoldLayerProcessor-generate_selectors)

- [`BaseRFourfoldLayerProcessor$clone()`](#method-BaseRFourfoldLayerProcessor-clone)

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

### `BaseRFourfoldLayerProcessor$process()`

Process the fourfold display layer.

#### Usage

    BaseRFourfoldLayerProcessor$process(
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

### `BaseRFourfoldLayerProcessor$needs_reordering()`

Whether the plot data must be reordered before drawing; a Base R layer
is read from the recorded call and never is

#### Usage

    BaseRFourfoldLayerProcessor$needs_reordering()

#### Returns

FALSE

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$recorded_table()`

The 2x2 table of counts the call was handed, when it is one.

Guarded by
[`fourfold_decline_reason()`](https://r.maidr.ai/reference/fourfold_decline_reason.md),
the same predicate `detect_layer_type()` asks, so dispatch and
extraction cannot disagree about which calls are readable.

Used for the COUNTS and the shape only. The level names and the axis
names come from `drawn_dimnames()` instead, which is not the same thing
– see there.

#### Usage

    BaseRFourfoldLayerProcessor$recorded_table(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

A 2x2 table, or NULL

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$drawn_dimnames()`

The dimnames
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
itself labels the chart with.

NOT `dimnames(recorded_two_way_table(...))`, and the difference is the
whole point.
[`recorded_two_way_table()`](https://r.maidr.ai/reference/recorded_two_way_table.md)
repairs dimnames through
[`as.table()`](https://rdrr.io/r/base/table.html);
[`graphics::fourfoldplot`](https://rdrr.io/r/graphics/fourfoldplot.html)
repairs them from `dimnames(x)` as handed, after reshaping a 2-D `x` to
`2 x 2 x 1`. Its own source:


    if (length(dim(x)) == 2L)
        x <- if (is.null(dimnames(x))) array(x, c(dim(x), 1L))
             else array(x, c(dim(x), 1L), c(dimnames(x), list(NULL)))
    dnx <- dimnames(x)
    if (is.null(dnx)) dnx <- vector("list", 3L)
    for (i in which(sapply(dnx, is.null))) dnx[[i]] <- LETTERS[seq_len(dim(x)[i])]
    if (is.null(names(dnx))) i <- 1L:3L else i <- which(is.null(names(dnx)))
    if (any(i)) names(dnx)[i] <- c("Row", "Col", "Strata")[i]

reproduced here rather than approximated. For an `ftable` the two
disagree completely: `dimnames(ftable(tb))` is NULL, so the chart is
labelled `Row: A`, `Col: A`, `Row: B`, `Col: B` – measured off the text
grobs – while `as.table(ftable(tb))` reconstructs `Treatment`/`Outcome`
and `Drug`/`Placebo`/`Cured`/`Not`. Reading the levels off
[`as.table()`](https://rdrr.io/r/base/table.html) would announce six
strings that appear nowhere on the page, which is \#268's own failure
displaced from the numbers onto the labels.

The `which(is.null(names(dnx)))` line is upstream's, quirk included:
[`is.null()`](https://rdrr.io/r/base/NULL.html) returns one logical, so
that expression is always `integer(0)` and the `Row`/`Col` default fires
only when `names(dimnames(x))` is entirely NULL. A PARTIALLY named
`dimnames` is therefore never repaired, and measured,
`names(dimnames(t)) <- c("Answer", "")` makes the chart literally draw
`": hi"` and `": lo"`. `extract_axis_titles()` substitutes `"Col"` there
rather than announce an empty label – deliberately better than the
chart, and the one place this reading is not identical to it.
`test-base-r-fourfoldplot.R` pins the chart's wrong answer as well as
ours.

#### Usage

    BaseRFourfoldLayerProcessor$drawn_dimnames(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

A length-3 named list of dimnames, or NULL

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$extract_data()`

Read the 2x2 grid of counts out of the recorded call.

Rows of the emitted grid are the table's FIRST dimension, top to bottom,
and its columns the SECOND, left to right – measured from the drawing,
where `polygon-1` (cell `[1, 1]`) is the upper-left quadrant and the top
and bottom labels carry `names(dimnames(x))[1]`. That is the transpose
of what [`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
does with the same argument, and it is not a convention chosen here.

The level names come from `drawn_dimnames()`, so they are the strings
the chart puts beside each quadrant.

#### Usage

    BaseRFourfoldLayerProcessor$extract_data(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

List with points, x and y, empty when there is no readable table

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$levels_of()`

The level names of one table dimension, as drawn.

`drawn_dimnames()` is NULL only when the recorded first argument has no
2-D [`dim()`](https://rdrr.io/r/base/dim.html) at all, which a readable
call cannot have; the fallback is there so a malformed `layer_info` in a
test yields level names rather than an error.

#### Usage

    BaseRFourfoldLayerProcessor$levels_of(named, i, fallback)

#### Arguments

- `named`:

  The list `drawn_dimnames()` returned, or NULL

- `i`:

  Which dimension, 1 or 2

- `fallback`:

  Level names to use when there are none drawn

#### Returns

A character vector of level names

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$extract_axis_titles()`

Name the axes the way the chart places the dimensions.

`x` is the SECOND dimension, because measured the columns run left to
right; `y` is the first, because the rows run top to bottom. `z` names
what the numbers are rather than a dimension of the table – a reader
told "Outcome" for the value would be given a level name where a number
is.

`"Count"` is the contingency-table convention and not a claim that the
values are whole numbers: measured,
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
draws non-integer cells happily (`1.5, 2.5, 3.5, 4.5` gives radii
`0.5774, 0.7454, 0.8819, 1.0000` and the ratio check passes).

No
[`recorded_axis_label()`](https://r.maidr.ai/reference/recorded_axis_label.md)
call, unlike the assocplot processor. Measured,
`names(formals(graphics::fourfoldplot))` is exactly
`x, color, conf.level, std, margin, space, main, mfrow, mfcol` – no
`xlab`, no `ylab`, no `...` – and `fourfoldplot(tab, xlab = "X")` stops
with "unused argument". Reading a label that the function rejects would
be dead code asserting an argument that cannot exist.

#### Usage

    BaseRFourfoldLayerProcessor$extract_axis_titles(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Canonical axes list

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$extract_main_title()`

The title the call was given, if any.

#### Usage

    BaseRFourfoldLayerProcessor$extract_main_title(layer_info)

#### Arguments

- `layer_info`:

  Information about the recorded plot call

#### Returns

Character scalar, empty when the author wrote no title

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$wedge_names()`

The four wedge grobs of one fourfold panel, or NULL.

Discriminated by polygon count and vertex count, NOT by `gp$fill`. Fill
looks like the exact discriminator and is not: measured,
`fourfoldplot(tb, std = "ind.max", color = "steelblue")` leaves two
quadrants with `fill = NA`, because
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) does
not validate `color`'s length and its draw calls index it as
`color[1 + (d > 1)]` / `color[2 - (d > 1)]`. A fill-keyed search finds
two wedges there and the layer would ship with no selectors at all, for
a chart that is perfectly readable.

What is measured to be stable:

- one panel draws **exactly 13** polygons (4 wedges, 8 confidence arcs,
  1 frame) or **exactly 5** when `conf.level` is `0` or `FALSE`. The arc
  count is 8 or 0 and never anything else – `conf.level` produces two
  `for (j in 1:4)` loops guarded by `is.numeric(conf.level)`, and every
  other value (`1`, `-0.1`, `NA`, a length-2 vector, `NULL`) is rejected
  by [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  itself. Measured, `k` panels draw `13k` or `5k`: `UCBAdmissions` gives
  78 and 30, so this count also refuses another figure's grob tree.

- the wedges are always the first four in
  [`find_graphics_plot_grobs()`](https://r.maidr.ai/reference/find_graphics_plot_grobs.md)
  order, because `drawPie()` runs before the rings and before the frame
  at every `conf.level`;

- every quarter disc has **501** vertices (`drawPie(n = 500)` plus the
  centre point) and the frame is the only **4**-vertex polygon.

#### Usage

    BaseRFourfoldLayerProcessor$wedge_names(gt, plot_index)

#### Arguments

- `gt`:

  Grob tree to search

- `plot_index`:

  The plot (panel) index the grob names carry

#### Returns

The four wedge grob names, or NULL when this is not one panel

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$radii_agree()`

Whether the wedges on the page are the counts in the call.

`radius / sqrt(count)` constant across the four quadrants, to a relative
spread of `1e-8`. Measured headroom on the worst-conditioned tables that
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) will
draw at all – `c(1e-9, 1, 1, 1)` (`2.220e-16`), `c(1, 2, 3, 1e18)`
(`2.068e-16`) and the non-integer `c(1.5, 2.5, 3.5, 4.5)` (`1.178e-16`)
– is eight orders below the threshold, while an asymmetric table's
`margins` drawing checked against its counts gives `7.616e-01`.
(`c(1, 1e15, 1, 1)` is not in that list because `radii_agree()` is never
asked about it – not because it errors. Measured,
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
returns normally there with a "NaNs produced" warning and emits ZERO
polygon grobs under `ind.max` and `all.max`, so `wedge_names()` refuses
it on the polygon count first. Under the default `margins` the same
table does draw 13 polygons – radii
`0.00017782794, 0.99999998, 0.99999998, 0.00017782794` – but no
`margins` call reaches a processor.)

A zero count makes `radius / sqrt(count)` `0/0`, so those cells are held
to `radius == 0` instead – measured, a zero cell still emits a full
501-vertex polygon at the origin, so the grob is there and addressable.

**The check is vacuous when fewer than two cells are non-zero**: one
non-zero cell makes the relative deviation identically 0 whatever the
radius is. Measured, `0, 0, 0, 160` under `ind.max` draws radii
`0, 0, 0, 1` and would pass an unguarded check against any table with
the same three zeros. Two non-zero cells are required before the ratio
is treated as evidence, so such a chart announces its counts and
highlights nothing.

#### Usage

    BaseRFourfoldLayerProcessor$radii_agree(gt, names, counts)

#### Arguments

- `gt`:

  Grob tree to search

- `names`:

  The four wedge grob names, in drawing order

- `counts`:

  The four recorded counts, in `c(tab)` order

#### Returns

TRUE when the drawing carries the recorded counts

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$generate_selectors()`

Address the quadrant the chart drew each count into.

Each quadrant is its own polygon grob, so each needs its own selector –
the pie's situation, not the barplot's. Two orderings compose here, and
they run in opposite directions:

- **The drawing is column-major.** Table cell `[r, c]` is polygon
  `(c - 1) * 2 + r`. Measured on the exported SVG of
  `fourfoldplot(tb, std = "ind.max")` with `c(tab) = 10, 40, 90, 160`,
  the polygon centroids in screen coordinates (the root `<g>` carries
  `translate(0, 360) scale(1, -1)`, so screen `y` is `360 - y`) are
  `polygon-1 (221, 158)` upper LEFT, `polygon-2 (190, 224)` lower LEFT,
  `polygon-3 (345, 114)` upper RIGHT, `polygon-4 (376, 268)` lower
  RIGHT, and the count labels sit at `10 (90, 55)`, `40 (90, 305)`,
  `90 (414, 55)`, `160 (414, 305)`. So table row 1 is the TOP row on the
  page, which is the row `extract_data()` emits first.

- **The `heat` trace reverses the numbers and not the selectors.** In
  the bundled `maidr-4.8.0/maidr.js` the constructor is
  `this.y=[...t.y].reverse(),this.heatmapValues=[...t.points].reverse()`,
  while `mapToSvgElements()`'s array-of-arrays branch walks `e[i]` index
  for index. Its bare-string branch immediately below DOES reverse
  (`let a=t-1-e`), which is what makes the asymmetry easy to miss. So
  `highlightValues[0]` lines up with `points`' LAST row.

Grid row 1 is therefore the BOTTOM wedges:
`[[polygon-2, polygon-4], [polygon-1, polygon-3]]`. **The wrong answer
is to emit it index-aligned with `points`**, top row first – it reads
correctly and highlights the vertically mirrored quadrant on every cell
of every fourfold plot: `row 0, col 0` then announces `Placebo / 40`
while lighting the wedge drawn for `Drug / 10`.
`test-base-r-fourfoldplot.R` pins the bottom-first order against that.
[`image()`](https://r.maidr.ai/reference/base-r-wrappers.md)/[`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)
is the precedent – measured on `image(matrix(1:6, 2))`, `points[[1]]` is
the top row while `selectors[[1]]` is `rect:nth-child(1)`, the lowest
rect on the page – and `NEWS.md` records fixing the same mirror there.

Returns [`list()`](https://rdrr.io/r/base/list.html) when the drawing
and the recorded call disagree. The numbers are still announced – they
are what the call was handed – and nothing highlights, rather than a
highlight landing on another panel's quadrant.

#### Usage

    BaseRFourfoldLayerProcessor$generate_selectors(
      layer_info,
      gt = NULL,
      extracted_data = NULL
    )

#### Arguments

- `layer_info`:

  Information about the recorded plot call

- `gt`:

  Grob tree to search

- `extracted_data`:

  Unused; the counts are re-read from the call

#### Returns

A 2x2 nested list of selectors, or an empty list

------------------------------------------------------------------------

### `BaseRFourfoldLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    BaseRFourfoldLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
