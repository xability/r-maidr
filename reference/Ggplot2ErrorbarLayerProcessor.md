# ggplot2 Error Bar Layer Processor

Processes ggplot2's uncertainty geoms –
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
[`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
[`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
and
[`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
– into MAIDR's `error_bar` layer.

Uncertainty is usually the finding rather than the decoration: whether
two group means differ is answered by whether their intervals overlap.
Until this processor existed every one of these geoms fell through to
`Ggplot2UnknownLayerProcessor`, so the interval was dropped and that
comparison was unavailable to a MAIDR reader.

### Reading the right pair of bounds

The trap this class exists to avoid is that ggplot2's built data carries
**both** pairs for most of these geoms, and only one of them is the
interval. A vertical
[`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
computes:

      x  y  ymin ymax  xmin  xmax  flipped_aes
      1 4.2  3.8  4.6  0.55  1.45  FALSE

`ymin`/`ymax` are the interval; `xmin`/`xmax` are the *cap width* – how
wide the little crossbars are drawn, which is a styling parameter and
not data at all. Reading the wrong pair yields a chart describing the
cap geometry, which is both wrong and plausible-looking.

Which pair is the interval is decided by the layer's orientation, and
ggplot2 records that in two different ways depending on the geom:

- `geom_errorbar(orientation = "y")` and friends set a `flipped_aes`
  column to `TRUE` in the built data.

- [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  has no `flipped_aes` column at all – it is horizontal by construction.

Both are handled, because a layer that read only `flipped_aes` would
treat every
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
as vertical and emit the cap heights as the interval.

## Super classes

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
[`Ggplot2PointLayerProcessor`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.md)
-\> `Ggplot2ErrorbarLayerProcessor`

## Methods

### Public methods

- [`Ggplot2ErrorbarLayerProcessor$process()`](#method-Ggplot2ErrorbarLayerProcessor-process)

- [`Ggplot2ErrorbarLayerProcessor$is_horizontal_layer()`](#method-Ggplot2ErrorbarLayerProcessor-is_horizontal_layer)

- [`Ggplot2ErrorbarLayerProcessor$extract_interval_data()`](#method-Ggplot2ErrorbarLayerProcessor-extract_interval_data)

- [`Ggplot2ErrorbarLayerProcessor$resolve_estimates()`](#method-Ggplot2ErrorbarLayerProcessor-resolve_estimates)

- [`Ggplot2ErrorbarLayerProcessor$resolve_category_labels()`](#method-Ggplot2ErrorbarLayerProcessor-resolve_category_labels)

- [`Ggplot2ErrorbarLayerProcessor$category_axis_labels()`](#method-Ggplot2ErrorbarLayerProcessor-category_axis_labels)

- [`Ggplot2ErrorbarLayerProcessor$clone()`](#method-Ggplot2ErrorbarLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`Ggplot2PointLayerProcessor$extract_axes_labels()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axes_labels)
- [`Ggplot2PointLayerProcessor$extract_axis_grid_info()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_axis_grid_info)
- [`Ggplot2PointLayerProcessor$extract_data()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-extract_data)
- [`Ggplot2PointLayerProcessor$find_children_by_type()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_children_by_type)
- [`Ggplot2PointLayerProcessor$find_panel_grob()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-find_panel_grob)
- [`Ggplot2PointLayerProcessor$generate_selectors()`](https://r.maidr.ai/reference/Ggplot2PointLayerProcessor.html#method-generate_selectors)

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$process()`

Process the error bar layer.

#### Usage

    Ggplot2ErrorbarLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
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

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data, axes, type and orientation

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$is_horizontal_layer()`

Decide whether the interval runs along x rather than y.

Reads `flipped_aes` when the built data carries it, and falls back to
the geom class for
[`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
which is horizontal by construction and therefore has no such column to
read.

#### Usage

    Ggplot2ErrorbarLayerProcessor$is_horizontal_layer(plot, layer_data)

#### Arguments

- `plot`:

  The ggplot2 object

- `layer_data`:

  This layer's computed rows

#### Returns

TRUE when the interval spans the x axis

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$extract_interval_data()`

Build the MAIDR points for this layer.

The emitted shape names the category `x` and the magnitude `y` in both
orientations, with the bounds in `yMin`/`yMax`, and lets `orientation`
say which is on screen where. That is the shape MAIDR's `ErrorBarTrace`
consumes: it reads the magnitude as `y`/`yMin`/`yMax` with no
orientation branch, so emitting screen-aligned keys would leave a
horizontal chart with no interval at all.

A row missing its bounds still emits its estimate. A one-sided interval
is a real chart, and dropping the point for want of its other half would
lose the estimate too.

#### Usage

    Ggplot2ErrorbarLayerProcessor$extract_interval_data(
      built,
      layer_data,
      is_horizontal,
      panel_id = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  This layer's computed rows

- `is_horizontal`:

  Whether the interval spans the x axis

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of MAIDR interval points

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$resolve_estimates()`

Resolve the estimate each interval is centred on.

The estimate aesthetic is **optional** on these geoms, and leaving it
out is idiomatic rather than exotic: `geom_errorbar(aes(x, ymin, ymax))`
layered over a
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html) is
the standard way to draw a bar chart with error bars, and it builds with
no `y` column at all.
[`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
is the same. Requiring the column dropped every such layer silently – no
interval, no estimate, no error.

When it is absent the chart genuinely draws no estimate, only a span, so
the centre of that span is used. That is a property of the drawn bar
rather than a claim about an unobserved estimate, and it is what keeps
the bounds – which are the real data here – reachable at all. It is NOT
the mean for an asymmetric interval, and nothing here pretends it is: a
layer that carries `y` always uses the value the chart drew.

#### Usage

    Ggplot2ErrorbarLayerProcessor$resolve_estimates(
      layer_data,
      value_col,
      min_col,
      max_col
    )

#### Arguments

- `layer_data`:

  This layer's computed rows

- `value_col`:

  The estimate column for this orientation

- `min_col`:

  The lower bound column for this orientation

- `max_col`:

  The upper bound column for this orientation

#### Returns

A numeric vector of estimates, or NULL when neither the estimate nor a
pair of bounds is present

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$resolve_category_labels()`

Recover the names behind a discrete category axis.

ggplot2 maps a discrete axis onto integer positions before it computes
the layer, so the built data carries `1, 2, 3` where the chart draws
`control, high dose, low dose`. Announcing the positions would name
something the reader cannot find anywhere on the chart – and the
positions are assigned in the scale's order, not the data's, so they do
not even read as row numbers.

The labels come from the panel's scale rather than from the data frame,
which is what makes the position an index into them.

#### Usage

    Ggplot2ErrorbarLayerProcessor$resolve_category_labels(
      built,
      layer_data,
      category_col,
      panel_id = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `layer_data`:

  This layer's computed rows

- `category_col`:

  Which built column carries the category

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A list of labels – strings for a discrete axis, numbers for a continuous
one

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$category_axis_labels()`

Read the break labels of the category axis, when discrete.

#### Usage

    Ggplot2ErrorbarLayerProcessor$category_axis_labels(
      built,
      category_col,
      panel_id = NULL
    )

#### Arguments

- `built`:

  Built plot data

- `category_col`:

  Which built column carries the category

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

A character vector of labels, or NULL on a continuous axis

------------------------------------------------------------------------

### `Ggplot2ErrorbarLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2ErrorbarLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
