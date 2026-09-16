# Declare that a rectangle layer draws a schedule

`maidr_gantt()` is
[`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
with one thing added: the author saying that these rectangles are
intervals in lanes. A declared layer is read as a `gantt` – lanes named,
intervals announced, every bar highlightable – where the same rectangles
drawn with
[`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
are left unread and cost the whole chart its interactivity.

Nothing about the picture changes. The declaration is carried on the
layer object, not in the aesthetics, so the same
`xmin`/`xmax`/`ymin`/`ymax` the author would have written to
[`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
produce the same chart: measured on ggplot2 3.4.4, the built data is
[`identical()`](https://rdrr.io/r/base/identical.html) to the bare
[`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
layer's and the panel's `x.range` and `y.range` are identical too.
Swapping `geom_rect(` for `maidr_gantt(` moves nothing on the page.

## Usage

``` r
maidr_gantt(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  lane_axis = c("y", "x"),
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
)
```

## Arguments

- mapping:

  Aesthetics, as for
  [`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html):
  `xmin`, `xmax`, `ymin` and `ymax` are required, and every other
  rectangle aesthetic (`fill`, `colour`, `alpha`, ...) behaves exactly
  as it does there.

- data:

  The layer's data, as for
  [`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html).

- position:

  Position adjustment, as for
  [`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html).

- ...:

  Other arguments passed to the layer, as for
  [`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  – except `stat`, which that function takes as a formal and this one
  does not accept. A declared schedule is always drawn from the author's
  own bounds, so the stat is fixed at `"identity"`; measured, a `stat`
  written here lands in `params`, is recognised by neither the geom nor
  the stat, and is dropped with the warning
  `Ignoring unknown parameters`. Aesthetics and geom parameters pass
  through exactly as they do to
  [`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  – measured, a misspelled aesthetic and a misspelled parameter each
  raise the identical warning from both.

- lane_axis:

  Which axis the lanes run up: `"y"` (the default) for the ordinary
  horizontal schedule – lanes stacked up y, spans running along x – or
  `"x"` for the mirror image. It selects which pair of bounds becomes
  the span and which becomes the lane; it is not a guess the package
  makes.

- na.rm:

  If `FALSE` (the default), rows with missing values are removed with a
  warning.

- show.legend:

  Whether this layer is included in the legends.

- inherit.aes:

  If `FALSE`, the plot's default aesthetics are not inherited.

## Value

A ggplot2 layer, to be added to a plot with `+`.

## Why the author is asked

A rectangle layer carries no evidence of what it means. Five structural
rules were measured against eight charts on ggplot2 3.4.4, and the best
of them – bands partition on the lane axis, more than one band, more
than one distinct span, minus a complete-lattice veto – scored 6 of 8
and still claimed a heatmap with one cell missing and a two-region
highlight. The table is recorded above the reading itself, in
`R/ggplot2_adapter.R`. A monotone waterfall and a one-task-per-lane
schedule are the same rectangles, so there is nothing in the geometry to
separate; asking the author is the only unfalsified rule.

The consequence is that this is trusted. `maidr_gantt()` over heatmap
coordinates announces a heatmap as a schedule, and the package believes
it, because any guard strong enough to catch that is the rule the
measurements above ruled out.

## What it costs not to declare

An undeclared
[`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
layer reads as `"unknown"`, which drops the whole plot to a static image
with the "Plot contains unsupported elements" warning. That is unchanged
by this function, deliberately: every chart already written keeps
exactly the reading it has today.

## Lane names

With numeric `ymin`/`ymax` the lane axis is continuous and has no level
names to borrow, so a lane is named by the single explicit tick drawn
inside it –
`scale_y_continuous(breaks = 1:3, labels = c("design", "build", "test"))`
– and by its position on the axis otherwise. A tick whose label is a
rendering of its own number is a coordinate rather than a name: measured
on the default scale the panel's labels are `NA, 1, 2, 3, NA`, each one
its own break written out, and a lane called `"2"` says less than a lane
called by the position 2 it sits at.

## See also

[`save_html()`](https://r.maidr.ai/reference/save_html.md) and
[`show()`](https://r.maidr.ai/reference/show.md) for rendering the
declared chart

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  tasks <- data.frame(
    lane = c(1, 2, 3, 2),
    start = c(0, 3, 8, 12),
    end = c(3, 8, 11, 15)
  )

  schedule <- ggplot2::ggplot(tasks) +
    maidr_gantt(ggplot2::aes(
      xmin = start, xmax = end,
      ymin = lane - 0.4, ymax = lane + 0.4
    )) +
    ggplot2::scale_y_continuous(
      breaks = 1:3,
      labels = c("design", "build", "test")
    ) +
    ggplot2::labs(x = "week", y = "task")

  # The same rectangles written with `geom_rect()` draw the same chart and
  # are left unread, which costs the plot its interactivity.
  if (interactive()) {
    show(schedule)
  }
}
```
