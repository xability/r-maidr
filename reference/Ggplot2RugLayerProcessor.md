# Rug Layer Processor

Reads
[`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html) as
the observations it marks.

A rug draws one short tick per row against the edge of the panel. What
it states is the **raw data** – which is exactly what the density curve
or histogram it usually accompanies does not. Until \#222 the layer
reached `Ggplot2UnknownLayerProcessor`: a rug-only chart emitted one
empty layer and a rug beside a scatter added an empty one a reader could
land on and find nothing in.

Read as **points**, which is the reading py-maidr settled on for
`seaborn.rugplot` (xability/py-maidr#250). `length` is one number for
the whole layer, so a tick's *length* is decoration and only its
position is data – the same argument the event-plot reading makes about
its ticks. The coordinate across the tick is emitted as a constant
rather than as the tick's own base, because that base is a fraction of
the panel and would read as data at whatever scale the other axis
happens to use.

### One layer per axis

[`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html)
defaults to `sides = "bl"`, so on a chart with both aesthetics mapped it
marks **both** – and the built data carries both columns. So this emits
up to two layers: the x observations and the y observations.

Not one per drawn grob. `sides = "trbl"` draws the same x observations
at top *and* bottom, and emitting that twice would have a reader
navigate the same numbers under two names. Measured on four rows:

    sides="b"      GRID.segments.1  : x (n=4)
    sides="l"      GRID.segments.41 : y (n=4)
    sides="bl"     GRID.segments.78 : x (n=4)   GRID.segments.79 : y (n=4)
    sides="trbl"   .116: x   .117: x   .118: y   .119: y

A side is drawn only where the matching aesthetic exists –
`sides = "bl"` with only `aes(x = v)` gives one grob – so the layers
follow the built data's columns rather than a parse of the `sides`
string.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2RugLayerProcessor`

## Methods

### Public methods

- [`Ggplot2RugLayerProcessor$process()`](#method-Ggplot2RugLayerProcessor-process)

- [`Ggplot2RugLayerProcessor$layer_rows()`](#method-Ggplot2RugLayerProcessor-layer_rows)

- [`Ggplot2RugLayerProcessor$marked_axes()`](#method-Ggplot2RugLayerProcessor-marked_axes)

- [`Ggplot2RugLayerProcessor$axis_layer()`](#method-Ggplot2RugLayerProcessor-axis_layer)

- [`Ggplot2RugLayerProcessor$axis_labels()`](#method-Ggplot2RugLayerProcessor-axis_labels)

- [`Ggplot2RugLayerProcessor$generate_selectors()`](#method-Ggplot2RugLayerProcessor-generate_selectors)

- [`Ggplot2RugLayerProcessor$find_segments_name()`](#method-Ggplot2RugLayerProcessor-find_segments_name)

- [`Ggplot2RugLayerProcessor$position_among_rugs()`](#method-Ggplot2RugLayerProcessor-position_among_rugs)

- [`Ggplot2RugLayerProcessor$rug_trees()`](#method-Ggplot2RugLayerProcessor-rug_trees)

- [`Ggplot2RugLayerProcessor$wraps_a_rug()`](#method-Ggplot2RugLayerProcessor-wraps_a_rug)

- [`Ggplot2RugLayerProcessor$axis_of()`](#method-Ggplot2RugLayerProcessor-axis_of)

- [`Ggplot2RugLayerProcessor$clone()`](#method-Ggplot2RugLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_data)
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

### `Ggplot2RugLayerProcessor$process()`

Process the rug layer

#### Usage

    Ggplot2RugLayerProcessor$process(
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

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

A single layer, or a `multi_layer` result carrying two

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$layer_rows()`

This layer's rows of the built data

Not `LayerProcessor$get_layer_built_data()`, and the difference is the
point rather than an oversight. That method falls back to **all**
panels' rows when the panel-scoped subset comes back empty, and a rug is
a chart where an empty subset is real: a
[`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html)
cell that no row falls in draws no ticks. Measured on a grid with two
populated cells of two ticks each –

    panel 1 -> layer_rows: 2   get_layer_built_data: 2
    panel 2 -> layer_rows: 0   get_layer_built_data: 4
    panel 3 -> layer_rows: 0   get_layer_built_data: 4
    panel 4 -> layer_rows: 2   get_layer_built_data: 2

– so the inherited helper would have the two empty panels each announce
all four observations, drawn in the other two. An empty subset is
returned as it is, and `process()` reads it as the "no layer" it is.

Written down because the two look interchangeable and are not: swapping
this for the inherited helper is a one-line simplification that
reintroduces the bug silently. `test-ggplot2-rug.R` pins the panel that
draws nothing.

#### Usage

    Ggplot2RugLayerProcessor$layer_rows(built, panel_id = NULL)

#### Arguments

- `built`:

  Built plot data

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A data frame, or NULL

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$marked_axes()`

Which axes this rug actually marks

Both halves are needed, and measuring showed why. The built data's
columns are not enough on their own: `geom_rug(sides = "b")` on
`aes(v, w)` carries a `y` column and draws no left rug, and reading the
columns alone emitted a y layer for observations the chart never marked
– a whole layer invented out of an aesthetic that was mapped for the
*scatter* underneath.

`sides` is not enough either, in the other direction: it defaults to
`"bl"` on every rug, and one drawn over `aes(x = v)` alone has no `y` to
mark. So a side counts only where both agree, which is exactly what the
drawing does – measured, `sides = "bl"` gives two grobs with both
aesthetics mapped and one with only `x`.

#### Usage

    Ggplot2RugLayerProcessor$marked_axes(rows, layer)

#### Arguments

- `rows`:

  This layer's rows of the built data

- `layer`:

  This layer, for its `sides`

#### Returns

A character vector, a subset of `c("x", "y")`, in that order

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$axis_layer()`

One axis' observations as a point layer

#### Usage

    Ggplot2RugLayerProcessor$axis_layer(plot, layout, rows, axis, gt, panel_ctx)

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `rows`:

  This layer's rows of the built data

- `axis`:

  `"x"` or `"y"`

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

A layer list

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$axis_labels()`

Name the axes, calling the strip the ticks sit in what it is

The axis carrying the observations keeps the chart's own label. The one
across the ticks is renamed even where the caller labelled it: a rug
under a density curve has a real "density" label on that axis, and every
entry this layer emits sits at 0 rather than at any density.

#### Usage

    Ggplot2RugLayerProcessor$axis_labels(layout, axis)

#### Arguments

- `layout`:

  Layout information

- `axis`:

  `"x"` or `"y"`

#### Returns

An axes list

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$generate_selectors()`

Address each tick by the element it was drawn as

[`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html)
draws one `segmentsGrob` per side, and gridSVG exports that as one
element per segment carrying an id of the form `<grob>.1.<n>` – the
shape \#194 measured for
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html),
whose `GRID.segments.38.1.1` through `.4` follow built-data order.

The grob cannot be found by name: ggplot2 gives a rug layer no geom
prefix, so it arrives as grid's automatic `GRID.segments.N`, whose
number is a global counter and not stable between sessions. It is
located by class and by position instead, and read off the gtable being
exported rather than reconstructed.

Where a rug draws one axis **twice** – `sides = "tb"`, or `"trbl"` – the
first grob for that axis is addressed. The two are copies of one
observation, so highlighting one of them is partial; highlighting
neither is worse, and \#145 settled that a selector list which does not
match the point count is withdrawn wholesale rather than applied in
part. An empty list is returned when the grob cannot be resolved, for
that same reason: a guess at its name is worse than no highlighting.

#### Usage

    Ggplot2RugLayerProcessor$generate_selectors(
      plot,
      gt,
      axis,
      count,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `axis`:

  `"x"` or `"y"`

- `count`:

  How many ticks this layer emits

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

A list of CSS selectors, one per tick

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$find_segments_name()`

The grob holding this layer's ticks for one axis

[`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html)
wraps its grobs in a `gTree` of its own – measured, a `sides = "bl"` rug
gives `GRID.gTree.3` holding `GRID.segments.1` and `GRID.segments.2`,
and two rug layers give two such trees in layer order. So one layer's
grobs arrive as a block already, and there is nothing to slice.

That wrapping is also what tells a rug from its neighbours.
[`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
draws a **bare** `segments` grob directly under the panel:

    rug + segment    GRID.segments.117            <- the segment layer
                     GRID.gTree.120
                       GRID.segments.118          <- the rug, x
                       GRID.segments.119          <- the rug, y

So a candidate is a directly-held `gTree` with grid's automatic name
whose children are every one a `segments` grob, and the nth of those
belongs to the nth rug layer. Matching on the name is necessary as well
as the class: a layer ggplot2 *does* name arrives with its geom's
prefix, and one of those is not a rug whatever it holds.

Which axis a grob stands on it answers itself: a tick standing on x is
held constant in `y`, so `y0` is a single recycled value while `x0`
carries one entry per observation. The same property py-maidr's
`read_rug` uses, and it needs no reference to `sides`.

Where a rug draws one axis **twice** – `sides = "tb"`, or `"trbl"` – the
first grob for that axis wins. The two are copies of one observation, so
highlighting one of them is partial; highlighting neither is worse, and
\#145 settled that a selector list which does not match the point count
is withdrawn wholesale rather than in part.

#### Usage

    Ggplot2RugLayerProcessor$find_segments_name(plot, gt, axis, panel_ctx = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `axis`:

  `"x"` or `"y"`

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

The grob name, or NULL when it cannot be resolved

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$position_among_rugs()`

This layer's place among the plot's rug layers

Counted among its own kind, so a second
[`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html)
reaches its own grobs rather than the first one's – the rule
`Ggplot2GanttLayerProcessor$find_segments_name()` applies, for the same
reason.

#### Usage

    Ggplot2RugLayerProcessor$position_among_rugs(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

The 1-based position, or NULL when the layer cannot be found

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$rug_trees()`

The panel's rug wrappers, in drawing order

#### Usage

    Ggplot2RugLayerProcessor$rug_trees(gt, panel_ctx = NULL)

#### Arguments

- `gt`:

  Gtable object

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

A list of gTrees

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$wraps_a_rug()`

Whether a grob is one rug layer's wrapper

#### Usage

    Ggplot2RugLayerProcessor$wraps_a_rug(node)

#### Arguments

- `node`:

  A grob The name test is a guard rather than a live branch, and is kept
  as one deliberately. Measured across every geom that draws segments –
  boxplot, violin, errorbar, crossbar, pointrange, linerange, step, a
  reference line – **none** produces a gTree whose children are all
  segments, so today the class test alone decides and dropping the name
  test changes no reading. `test-ggplot2-rug.R` pins that measurement,
  so the ggplot2 release that ends it turns a test red rather than
  leaving this silently load-bearing.

- `node`:

  A grob

#### Returns

TRUE when it is a `GRID.gTree` of nothing but segments

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$axis_of()`

Which axis one segments grob's ticks stand on

#### Usage

    Ggplot2RugLayerProcessor$axis_of(grob)

#### Arguments

- `grob`:

  A `segments` grob

#### Returns

`"x"`, `"y"`, or NA when it says neither

------------------------------------------------------------------------

### `Ggplot2RugLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2RugLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
