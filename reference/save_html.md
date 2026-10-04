# Save Interactive Plot as HTML File

Save a ggplot2, lattice or Base R plot as an HTML file with interactive
MAIDR accessibility features.

## Usage

``` r
save_html(
  plot = NULL,
  file = "plot.html",
  use_cdn = NULL,
  width = NULL,
  height = NULL,
  ...
)
```

## Arguments

- plot:

  A ggplot2 object, a lattice (trellis) object, or NULL for Base R
  auto-detection

- file:

  File path where to save the HTML file (e.g., "plot.html")

- use_cdn:

  Logical. Controls where MAIDR.js is loaded from:

  - `TRUE`: Use CDN. The file is self-contained but needs internet
    access when it is viewed. It names the latest published MAIDR.js by
    version (looked up once per R session, or the bundled version when
    the lookup cannot be made); pin a version with
    `options(maidr.cdn_version = ...)`, see
    [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

  - `FALSE` or `NULL` (default): Use the bundled files. The MAIDR.js
    library is written to a `lib/` folder beside `file`, which has to
    travel with it.

- width, height:

  The size to draw the chart at, in inches: each a single positive
  number no larger than 50, or `NULL` (the default) for 7 x 5 in, 12 x 6
  in for a candlestick chart. A side not given takes its default. See
  **Chart size**.

- ...:

  Additional arguments passed to internal functions

## Value

The file path where the HTML was saved (invisibly)

## Details

By default the MAIDR.js library is written to a `lib/` folder beside
`file`, and the two have to be shared together: zip the folder that
holds both, or copy both. An `.html` sent on its own loads no MAIDR.js
and shows a plain, inaccessible chart. `use_cdn = TRUE` writes one
self-contained file instead, which needs internet access whenever it is
viewed and loads the latest published MAIDR.js from jsDelivr rather than
the copy bundled with this package.

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
The size is set by `width` and `height` in
[`show()`](https://r.maidr.ai/reference/show.md) and `save_html()`, by
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

A Base R chart's margins and text take the same room at every size, so a
chart can be too small for them – R itself stops with "figure margins
too large" at such a size. maidr draws the chart with the margins and
text size its [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md)
calls set, so it fits where R draws it with them. Asked for a size too
small, maidr stops too, with an error naming the size, rather than show
an empty chart: draw it larger. With no size asked for, a chart too
small for 7 x 5 in, such as a `par(mfrow)` grid of five rows or more, is
drawn on the 7 x 7 in page maidr laid every Base R chart out on before
it drew one at its size. Where that is too small too, it is drawn on the
smallest larger page that leaves each of its plots a sixth of an inch,
12 px, each way, each side grown in whole inches only as far as it
needs: 7 x 9 in for six rows, 12 x 5 in for twelve columns. A message
names the size it is drawn at. The picture of a Base R chart maidr
cannot read is held to its size in the same way.

## Examples

``` r
# ggplot2 bar chart
library(ggplot2)
p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_bar(stat = "identity")
# \donttest{
maidr::save_html(p, tempfile(fileext = ".html"))

# The same chart, 10 inches wide and 4 high
maidr::save_html(p, tempfile(fileext = ".html"), width = 10, height = 4)
# }

# ggplot2 violin plot
p_violin <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_violin(fill = "lightblue", alpha = 0.7) +
  labs(title = "MPG by Cylinders", x = "Cylinders", y = "MPG")
# \donttest{
maidr::save_html(p_violin, tempfile(fileext = ".html"))
# }

# lattice chart [experimental]
# \donttest{
if (requireNamespace("lattice", quietly = TRUE)) {
  p_lattice <- lattice::bwplot(factor(cyl) ~ mpg, data = mtcars)
  maidr::save_html(p_lattice, tempfile(fileext = ".html"))
}
# }

# Base R example (requires interactive session for function patching)
if (interactive()) {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  maidr::save_html(file = tempfile(fileext = ".html"))
}
```
