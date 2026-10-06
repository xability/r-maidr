# Display Interactive MAIDR Plot

Display a ggplot2, lattice or Base R plot as an interactive, accessible
visualization using the MAIDR (Multimodal Access and Interactive Data
Representation) system.

## Usage

``` r
show(
  plot = NULL,
  use_cdn = NULL,
  shiny = FALSE,
  as_widget = FALSE,
  width = NULL,
  height = NULL,
  ...
)
```

## Arguments

- plot:

  A ggplot2 object, a lattice (trellis) object, or NULL for Base R
  auto-detection

- use_cdn:

  Logical. Controls where MAIDR.js is loaded from:

  - `TRUE`: Use the jsDelivr CDN (requires internet), which loads the
    latest published MAIDR.js rather than the bundled copy. The version
    is looked up once per R session; pin one with
    `options(maidr.cdn_version = ...)`, see
    [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

  - `FALSE`: Use local bundled files (works offline, and makes no
    network request)

  - `NULL` (default): Use the bundled files, so the viewer works
    offline. With `as_widget = TRUE` the widget instead auto-detects
    internet availability and uses the CDN when online, as the Shiny
    path does.

- shiny:

  If TRUE, returns just the SVG content instead of full HTML document

- as_widget:

  If TRUE, returns an htmlwidget object instead of opening in browser

- width, height:

  The size to draw the chart at, in inches: each a single positive
  number no larger than 50, or `NULL` (the default) for 7 x 5 in, 12 x 6
  in for a candlestick chart. A side not given takes its default. With
  `as_widget = TRUE` they size the chart in the widget, not the widget,
  whose own CSS size is set on the widget returned:
  `widget$width <- "300px"`. See **Chart size**.

- ...:

  Additional arguments passed to internal functions

## Value

Invisible NULL. The plot is displayed in RStudio Viewer or browser as a
side effect.

## Details

Attaching maidr masks
[`methods::show()`](https://rdrr.io/r/methods/show.html). An object that
is not a plot maidr renders – an S4 object, a vector, a data frame – is
handed to [`methods::show()`](https://rdrr.io/r/methods/show.html), so
it prints as it did before maidr was attached. In a script or a package,
call `maidr::show()` and
[`methods::show()`](https://rdrr.io/r/methods/show.html) by name;
[`?"base-r-wrappers"`](https://r.maidr.ai/reference/base-r-wrappers.md)
lists everything else attaching maidr masks.

Under webR there is no browser to open, so the chart is added to the
page the session runs in: as an iframe in the element with id
`maidr-output`, or at the end of `<body>` when there is none. A page
that defines `globalThis.maidrWebRShow(html)`, or R code that sets
`options(maidr.webr_display = function(html) ...)`, receives the
document instead. A plotly, highcharter or echarts4r widget is shown the
same way, made accessible with
[`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
first; its document carries the chart library, a few megabytes. Any
other htmlwidget is refused, with the message
[`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
gives.

## Base R charts

A Base R chart is read from the plotting calls recorded on the current
device, and is the page that device shows: the last one. R draws a
high-level plot on a new page when it moves past the last panel of the
page it is on – every plot on a page of one panel, the fifth under
`par(mfrow = c(2, 2))`, the first after `par(mfrow = )`, `par(mfcol = )`
or [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) sets a
page up again – and
[`plot.new()`](https://rdrr.io/r/graphics/frame.html) and
[`frame()`](https://rdrr.io/r/graphics/frame.html) move on a panel as a
plot does. So after `hist(a); hist(b)` the chart is the histogram of `b`
alone, and after five plots under `par(mfrow = c(2, 2))` it is the
fifth, in the first panel of a 2 x 2 grid. Each plot of a grid is in the
panel R drew it in: a plot drawn after `par(new = TRUE)`, or with
`add = TRUE`, is drawn in the panel of the plot before it, one
`par(mfg = )` sends to a panel out of turn is in that panel, and a panel
[`plot.new()`](https://rdrr.io/r/graphics/frame.html) or
[`frame()`](https://rdrr.io/r/graphics/frame.html) passed over stays
empty. So it is where the call that set the grid up was not recorded:
one made through
[`graphics::par()`](https://rdrr.io/r/graphics/par.html) or
[`graphics::layout()`](https://rdrr.io/r/graphics/layout.html), before
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md), or before an
earlier `show()` or
[`save_html()`](https://r.maidr.ai/reference/save_html.md) on the
device. A plot drawn in a region of the page `par(fig = )` gave it, as
an inset is, or in a screen of
[`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md), is
drawn in that region, and read with the plot before it.
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`points()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`text()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`legend()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`title()`](https://r.maidr.ai/reference/base-r-wrappers.md),
[`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) and the
other low-level calls add to the plot they are drawn on: after
`par(mfg = )`, or `screen(n, new = FALSE)` of
[`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md),
sends R back to the panel or screen of an earlier plot, to that plot.
Drawn on a panel [`plot.new()`](https://rdrr.io/r/graphics/frame.html)
or [`frame()`](https://rdrr.io/r/graphics/frame.html) took, as a legend
of its own is, or on a plot maidr does not record, such as
[`smoothScatter()`](https://rdrr.io/r/graphics/smoothScatter.html), they
are drawn there, and read as part of no plot. Drawn over a plot after
`par(new = TRUE)` and
[`plot.new()`](https://rdrr.io/r/graphics/frame.html), as a second
series with an axis of its own is – also over the plot of an earlier
panel or screen `par(mfg = )` or
[`screen()`](https://rdrr.io/r/graphics/screen.html) sent R back to –
they are drawn in the coordinates they were drawn in, and read with that
plot. Nothing drawn on an earlier page reaches the chart: not its data,
its titles or the size it is drawn at. A page
[`replayPlot()`](https://rdrr.io/r/grDevices/recordplot.html) puts back,
from a plot
[`recordPlot()`](https://rdrr.io/r/grDevices/recordplot.html) saved on a
device that keeps a display list, is the page the chart is read from,
with what was drawn on it when it was saved and what has been drawn on
it since. A page that holds no plot maidr recorded – one R started with
[`plot.new()`](https://rdrr.io/r/graphics/frame.html) or
[`frame()`](https://rdrr.io/r/graphics/frame.html), with a plot maidr
does not record, or with one drawn while
[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) was in
effect, even with
[`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
[`text()`](https://r.maidr.ai/reference/base-r-wrappers.md) drawn on it
since, or one
[`replayPlot()`](https://rdrr.io/r/grDevices/recordplot.html) put back
from such a page, or from a plot saved in another session or on another
device – is not read as the plot before it: `show()` and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) stop, and say
so. Each figure of an R Markdown or Quarto document is read the same
way, from the calls on its own page.

## Chart size

A chart is drawn at a size in inches, as
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
and knitr's `fig.width` and `fig.height` size a figure, and its SVG is
72 pixels to the inch: a 10 x 4 in chart is 720 pixels wide and 288
high. The size is the room the chart is laid out in – how far apart its
ticks and labels are, how lattice arranges its panels, where Base R puts
its titles – and not what maidr reads out: the data, titles and axis
labels a reader hears are the same at every size. Only how a reader
moves between panels can change: lattice arranges the panels of a chart
conditioned on one variable with no `layout =` for the shape of the
page, 1 x 2 at 7 x 5 in and 2 x 1 at 5 x 8 in for two panels, and the
subplot grid a reader moves through follows; give `layout =` to keep it.
The size is set by `width` and `height` in `show()` and
[`save_html()`](https://r.maidr.ai/reference/save_html.md), by
`fig_width` and `fig_height` in
[`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md), and by
the chunk's `fig.width` and `fig.height` in an R Markdown or Quarto
document (see [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md)).
Nothing else sets it: not the size of the device a chart was drawn on,
nor the size of the window, viewer or Shiny output it is shown in, which
shrinks a chart wider than itself to fit.

Unset, a chart is 7 x 5 in. A candlestick chart is 12 x 6 in, and is
never drawn smaller than that: quantmod's
[`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md) needs
the room for its title, date range and date labels. A smaller size asked
for is enlarged, with a message naming the size the chart is drawn at. A
side larger than 50 in is refused, as
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
refuses one: the size is in inches, not the pixels
[`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md) takes.

A Base R chart's margins and text take the same room at every size, as
do the cells a
[`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) call sizes
with [`lcm()`](https://rdrr.io/r/graphics/layout.html), so a chart can
be too small for them – R itself stops with "figure margins too large",
or for those cells "figure region too large", at such a size. maidr
draws the chart with the margins and text size its
[`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls set, so
it fits where R draws it with them. Asked for a size too small, maidr
stops too, with an error naming the size, rather than show an empty
chart: draw it larger. With no size asked for, a chart too small for 7 x
5 in, such as a `par(mfrow)` grid of five rows or more, is drawn on the
7 x 7 in page maidr laid every Base R chart out on before it drew one at
its size. Where that is too small too, it is drawn on the smallest
larger page that leaves each of its plots a sixth of an inch, 12 px,
each way, each side grown in whole inches only as far as it needs: 7 x 9
in for six rows, 12 x 5 in for twelve columns. A message names the size
it is drawn at. The picture of a Base R chart maidr cannot read is held
to its size in the same way.

## Examples

``` r
# ggplot2 bar chart
library(ggplot2)
p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_bar(stat = "identity")
# \donttest{
maidr::show(p)

# The same chart, 10 inches wide and 4 high
maidr::show(p, width = 10, height = 4)
# }

# ggplot2 violin plot
p_violin <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_violin(fill = "lightblue", alpha = 0.7) +
  labs(title = "MPG by Cylinders", x = "Cylinders", y = "MPG")
# \donttest{
maidr::show(p_violin)
# }

# lattice chart [experimental]
# \donttest{
if (requireNamespace("lattice", quietly = TRUE)) {
  maidr::show(lattice::xyplot(mpg ~ wt, data = mtcars))
}
# }

# Base R example (requires interactive session for function patching)
if (interactive()) {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  maidr::show(width = 6, height = 4)
}
```
