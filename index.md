# maidr

## Overview

maidr (Multimodal Access and Interactive Data Representation) makes data
visualizations accessible to users with visual impairments. It converts
ggplot2 and Base R plots, and experimentally lattice charts, into
interactive, accessible HTML/SVG formats with keyboard navigation,
screen reader support, and sonification. maidr for R is the R binding of
[MAIDR](https://maidr.ai/), the JavaScript core developed by the
(x)Ability Design Lab at the University of Illinois Urbana-Champaign;
the same accessibility layer is available for Python as
[py-maidr](https://py.maidr.ai/).

The package provides two main functions:

- [`show()`](https://r.maidr.ai/reference/show.md) displays an
  interactive accessible plot in RStudio Viewer or browser
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) writes a
  plot to an HTML file, with the MAIDR.js library in a `lib/` folder
  beside it

## Installation

maidr requires R 4.0.0 or later. Install the stable release from CRAN:

``` r

install.packages("maidr")
```

Or install the development version from GitHub:

``` r

# Using pak (recommended)
pak::pak("xability/r-maidr")

# Alternative: using pacman (auto-installs if missing)
pacman::p_load_gh("xability/r-maidr")
```

The development version is built from source, and maidr includes C++
code, so this needs a compiler: Rtools on Windows, the Xcode command
line tools on macOS.

## Usage

### ggplot2

``` r

library(maidr)
library(ggplot2)

p <- ggplot(mpg, aes(x = class)) +
  geom_bar(fill = "steelblue") +
  labs(title = "Vehicle Classes", x = "Class", y = "Count")

# Display interactive accessible plot
show(p)

# Or save to file
save_html(p, "vehicle_classes.html")
```

### Base R

``` r

library(maidr)

# Create plot first
barplot(
  table(mtcars$cyl),
  main = "Cars by Cylinder Count",
  xlab = "Cylinders",
  ylab = "Count"
)

# Then call show() without arguments
show()
```

### plotly, highcharter and echarts4r widgets

[`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
makes an interactive chart from [plotly](https://plotly-r.com/)
([`plot_ly()`](https://rdrr.io/pkg/plotly/man/plot_ly.html),
[`ggplotly()`](https://rdrr.io/pkg/plotly/man/ggplotly.html)),
[highcharter](https://jkunst.com/highcharter/) or
[echarts4r](https://echarts4r.john-coene.com/) accessible. The chart is
read in the browser by the MAIDR adapter for the library that draws it,
so it works wherever the widget does: the viewer,
[`htmlwidgets::saveWidget()`](https://rdrr.io/pkg/htmlwidgets/man/saveWidget.html),
R Markdown, Quarto and Shiny.

``` r

library(maidr)
library(plotly)

plot_ly(mtcars, x = ~wt, y = ~mpg, type = "scatter", mode = "markers") |>
  maidr_htmlwidget()

# ggplotly() keeps your ggplot2 code
ggplotly(ggplot(mtcars, aes(wt, mpg)) + geom_point()) |>
  maidr_htmlwidget()
```

An echarts4r chart is switched to ECharts’ SVG renderer, which MAIDR
needs to highlight the mark being read. While an echarts4r chart shows
its legend, the visual highlight is off; audio, text and braille are not
affected.

### lattice

A lattice chart is used the way a ggplot2 object is: printing it opens
the maidr viewer, and [`show()`](https://r.maidr.ai/reference/show.md)
and [`save_html()`](https://r.maidr.ai/reference/save_html.md) take it.
Every lattice chart type maidr reads is experimental; the lattice table
under [Experimental Plot Types](#experimental-plot-types) lists them.

``` r

library(maidr)
library(lattice)

cylinders <- as.data.frame(table(Cylinders = mtcars$cyl))

p <- barchart(
  Freq ~ Cylinders,
  data = cylinders,
  origin = 0,
  main = "Cars by Cylinder Count",
  ylab = "Count"
)

# Printing the chart opens it in the maidr viewer
p

# show() is the explicit form; save_html() writes it to a file
show(p)
save_html(p, "cylinders.html")
```

A conditioned chart, such as `xyplot(mpg ~ wt | factor(cyl), mtcars)`,
is read one panel at a time: each panel is a subplot of its own, named
after its strip.

### Chart size

A chart is drawn at 7 x 5 inches unless you give it a size, in inches as
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
takes one, and its SVG is 72 pixels to the inch. The size is the room
the chart is laid out in; the data, titles and axis labels a reader
hears are the same at every size. Only a lattice chart conditioned on
one variable with no `layout =` changes for a reader: lattice arranges
its panels for the shape of the page, and the order a reader moves
through them follows, so give it `layout =` to keep one. A side over 50
in is refused, as
[`ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
refuses one, since it is most likely pixels.

``` r

show(p, width = 10, height = 4)
save_html(p, "wide.html", width = 10, height = 4)

# Base R: draw, then show at a size
barplot(table(mtcars$cyl))
show(width = 6, height = 4)

# Shiny: the chart's size; maidr_output()'s width and height size the output
output$plot <- render_maidr(p, fig_width = 10, fig_height = 4)
```

In R Markdown and Quarto the chunk’s `fig.width` and `fig.height` set
it. Nothing else does: not the device a Base R chart was drawn on, nor
the window or Shiny output a chart is shown in, which shrinks a wider
chart to fit. A candlestick chart is never drawn smaller than 12 x 6 in;
asked for less (in a document, by the chunk’s own options), maidr says
in a message the size it used. A Base R chart too small for its margins
and text, or for the cells a
[`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) sizes with
[`lcm()`](https://rdrr.io/r/graphics/layout.html), at the size you ask
for is an error naming the size. With no size asked for, one too small
for 7 x 5 in, such as a `par(mfrow)` grid of five rows, is drawn larger,
at 7 x 7 in or the smallest larger size that leaves each of its plots
room to be seen, and a message names the size.

### R Markdown and Quarto

[`library(maidr)`](https://github.com/xability/r-maidr) in a setup chunk
is all a document needs. Every plot it draws, with ggplot2, lattice or
Base R, becomes an accessible chart:

```` markdown
```{r setup, include = FALSE}
library(maidr)
library(ggplot2)
```

```{r cars, fig.cap = "Cars by cylinder count"}
ggplot(mtcars, aes(factor(cyl))) + geom_bar()
```
````

- **Charts are part of the page.** In HTML output (`html_document`,
  bookdown, Quarto, reveal.js, ioslides, slidy, flexdashboard and Quarto
  dashboards) each chart is an `<svg>` in the page, not an iframe, and
  the page loads maidr.js once however many charts it has: from the
  document’s `_files` folder, or embedded in it when the document is
  `self_contained` or uses `embed-resources`. **Tab** moves into a chart
  and **Shift+Tab** out of it. While a chart has the focus, its keys go
  to the chart, not to the slide deck, book or website around it.
- **Several charts in a chunk.** A chunk can return a chart,
  [`print()`](https://rdrr.io/r/base/print.html) several in a loop, or
  draw several Base R charts. Each takes the place of its own figure,
  with that figure’s caption, alt text and number, so `fig.cap`,
  `fig.alt`, bookdown’s `\@ref(fig:label)` and Quarto’s `@fig-`
  references work as they do for images. A figure that is not one chart
  maidr can read, such as a grid drawing or a chart something else was
  drawn over, stays knitr’s image. In R Markdown and bookdown a chart’s
  caption is plain text: Markdown, maths and `\@ref()` inside `fig.cap`
  are shown as written. A bookdown text reference,
  `fig.cap = "(ref:label)"`, brings them in, as Quarto does for the
  caption of a chart in a `fig-` chunk, which it writes itself.
- **Size.** A chart is drawn at its chunk’s `fig.width` and `fig.height`
  (or `fig.asp`, `fig.dim`, R Markdown’s `fig_width`/`fig_height` and
  Quarto’s `fig-width`/`fig-height`), in inches, as knitr draws figures:
  7 x 5 in in `html_document` and Quarto’s HTML, but 3 x 3 in in
  `html_vignette`, small enough that a Base R chart shows fewer tick
  labels unless a chunk sets a larger size. `out.width` still sets the
  width a chart is shown at, and a chart wider than the page shrinks to
  fit it. See [Chart size](#chart-size) for what the size changes.
- **Cache and animations.** A chunk cached with `cache = TRUE` brings
  its charts back; one cached with `cache = 1` or `cache = 2` shows
  knitr’s static figures when it is rendered again from the cache.
  `fig.show = "animate"` stays knitr’s animation.
- **Static figures are SVG.** In HTML output maidr records a chunk’s
  figures with svglite instead of knitr’s default png, so the ones that
  stay images are vector images too. A device a chunk names
  (`dev = "png"`), a document device other than png, and the device of a
  cached chunk, of an animation and of a chunk that crops its figures or
  uses `fig.process` are kept. To keep png for every chunk, set
  `options(maidr.knitr_dev = FALSE)` before rendering or in the setup
  chunk.
- **Other outputs.** In PDF, Word, Markdown (`github_document`), EPUB
  and xaringan output, plots are knitr’s figures, as without maidr. HTML
  that cannot hold a chart in the page, such as an HTML fragment or
  pagedown, keeps each chart in an iframe of its own.
- **Return or print a chart; do not
  [`show()`](https://r.maidr.ai/reference/show.md) it.** A chart a
  document returns or prints never opens the viewer.
  [`show()`](https://r.maidr.ai/reference/show.md) still does: in a
  document it opens a browser during the render and puts nothing in the
  page.
- **Turning it off.**
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) in a chunk
  knits the chunks after it as they would be without maidr, and
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) turns maidr
  back on. [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md)
  lasts for the R session, not only the document: a later document
  rendered in the same session, such as a later vignette of
  `R CMD build`, stays off too, so a document that turns maidr off
  should end with
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md). Documents
  that call [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) in
  their setup chunk keep working; the call is no longer needed there.
- **A session with maidr loaded.** Any document rendered in an R session
  where maidr is loaded – by
  [`library(maidr)`](https://github.com/xability/r-maidr) at the
  console, or by loading its namespace alone, as a package that imports
  maidr does – gets charts and svglite figures, whether or not it loads
  maidr itself. `options(maidr.auto_show = FALSE)` before the render
  prevents that, and `options(maidr.knitr_dev = FALSE)` keeps png
  figures.

## How maidr hooks into your session

- **Console.** [`library(maidr)`](https://github.com/xability/r-maidr)
  is all it takes. Printing a ggplot2 object, by typing `p` or
  `print(p)`, opens it in the maidr viewer; `show(p)` is the explicit
  form. Base R plotting calls are recorded, and
  [`show()`](https://r.maidr.ai/reference/show.md) with no argument
  opens the recorded chart.
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) writes any
  of them to a file.
- **lattice.** Printing a lattice chart opens the viewer too, through
  lattice’s own `print.function` option, which maidr sets once lattice
  is loaded. A print that shares its page with other charts (`split`,
  `position`, `more = TRUE`, `newpage = FALSE`), a print into a file
  device such as [`pdf()`](https://rdrr.io/r/grDevices/pdf.html) or
  [`png()`](https://rdrr.io/r/grDevices/png.html), and `plot(p)`, which
  lattice does not route through that option, are drawn by lattice as
  before, and so is a chart maidr cannot read.
- **R Markdown and Quarto.**
  [`library(maidr)`](https://github.com/xability/r-maidr) in a setup
  chunk is enough. Every plot the document draws becomes an accessible
  chart in place of its figure, including charts printed with `print(p)`
  in a loop and several Base R charts in one chunk; see [R Markdown and
  Quarto](#r-markdown-and-quarto).
- **Shiny.** Put
  [`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md) in
  the UI and
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) in
  the server, with its expression returning the ggplot2 or lattice chart
  rather than printing it; see
  [`vignette("shiny-integration", package = "maidr")`](https://r.maidr.ai/articles/shiny-integration.md).
- **Turning it off.**
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) stops
  interception for the session and
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) starts it
  again. `options(maidr.ggplot2 = FALSE)` leaves ggplot2 printing alone,
  `options(maidr.lattice = FALSE)` leaves lattice printing alone,
  `options(maidr.base_r = FALSE)` stops recording Base R calls, and
  `options(maidr.auto_show = FALSE)`, in `.Rprofile` to make it
  permanent, turns everything off. See
  [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).
- **What gets masked.** Attaching maidr puts its own copies of the Base
  R plotting functions, and of
  [`methods::show()`](https://rdrr.io/r/methods/show.html), ahead of the
  originals; R lists them at
  [`library(maidr)`](https://github.com/xability/r-maidr). Each records
  the call and passes through to the original, and
  [`show()`](https://r.maidr.ai/reference/show.md) hands anything that
  is not a plot back to
  [`methods::show()`](https://rdrr.io/r/methods/show.html). In a script
  or a package call
  [`maidr::show()`](https://r.maidr.ai/reference/show.md) by name, and
  attach vioplot, wordcloud or quantmod *before* maidr, or their own
  functions mask the wrappers and their charts go unrecorded. See
  [`?"base-r-wrappers"`](https://r.maidr.ai/reference/base-r-wrappers.html).

## Supported plot types

maidr supports a wide range of visualization types in both ggplot2 and
Base R, in the two tables below. It also reads lattice charts, but only
as experimental types, so lattice has no column here: its charts are
listed under [Experimental Plot Types](#experimental-plot-types).

### Basic Plot Types

| Plot Type | ggplot2 | Base R |
|----|----|----|
| Bar charts | [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html), [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html) | [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Grouped/Dodged bars | `position = "dodge"` | `beside = TRUE` |
| Stacked bars | `position = "stack"` | `beside = FALSE` |
| Pie charts | [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html) + `coord_polar("y")` | [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Histograms | [`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html) | [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Scatter plots | [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html) | [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Line plots | [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html) | `plot(type = "l")`, [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Step plots | [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html) | `plot(type = "s")`, `plot(type = "S")` |
| Box plots | [`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html) | [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Heatmaps | [`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html) | [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Contour plots | — ([`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html) is \[experimental\], see below) | [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| Violin plots | [`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html) | — ([`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html) is \[experimental\], see below) |
| Candlestick (OHLC) | [`tidyquant::geom_candlestick()`](https://business-science.github.io/tidyquant/reference/geom_chart.html) (+ `geom_ma()`, + patchwork volume) | [`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html) (OHLC-only; no TA / no volume) |
| Density/Smooth | [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html), [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html) | `lines(density())` |

Note: Volume bars and moving-average overlays for candlestick charts are
supported only on the ggplot2 + {tidyquant} + {patchwork} path. On the
Base R path,
[`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)
`TA` overlays (`addVo()`, `addSMA()`, `addEMA()`) — and the default `TA`
whenever the input `xts` carries a `Volume` column — fall back to native
(non-accessible) graphics with a one-time advisory.

### Advanced Plot Types

| Plot Type | ggplot2 | Base R |
|----|----|----|
| Faceted plots | [`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html), [`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html) | `par(mfrow/mfcol)` + loops |
| Multi-panel layouts | `patchwork` package | `par(mfrow)`, `par(mfcol)` |
| Multi-layered plots | Multiple `geom_*` layers | Sequential plot calls |

### Experimental Plot Types

> \[!WARNING\] **These are prototypes. Treat them as prototypes.** They
> are under active development, they are unstable, and **none of them
> has been through a user study**. Field names, announcement wording and
> navigation may change without a deprecation period, including in a
> patch release. If you are building something that has to keep working,
> build it on the plot types above.

Everything in the two tables above predates the plot coverage roadmap
([\#137](https://github.com/xability/r-maidr/issues/137)) and has been
exercised by real readers over real charts. Everything below was added
by that roadmap, by the base R sweeps that followed it
([\#251](https://github.com/xability/r-maidr/issues/251),
[\#262](https://github.com/xability/r-maidr/issues/262)) or with the
lattice reading
([\#333](https://github.com/xability/r-maidr/issues/333)), most inside a
few weeks.

Each was measured against the chart it reads — that is what the issues
and the tests record. But measuring that a reading is *faithful to the
drawing* is a different claim from establishing that it is *useful to a
reader*. Nobody has asked a blind or low-vision reader whether hearing
[`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) as a radar,
or navigating a
[`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) panel by
panel, is the right way to read one. Until that happens these are
proposals about how a chart could be read, not answers.

Feedback is exactly what would move one of these into the tables above.

Elsewhere in these docs — the example articles, the getting-started
vignette and the package help — an experimental type is marked
**\[experimental\]** after its name; a type with no mark is stable.
Wherever they list plot types, the stable ones come first and the
experimental ones follow in a section of their own, as they do here.

#### ggplot2

| Layer type | Drawn by |
|----|----|
| `area` | [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html), `geom_ribbon(aes(ymin = 0, ...))` |
| `stacked_area` | stacked [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html) |
| `stacked_normalized_area` | `geom_area(position = "fill")` |
| `stacked_normalized_bar` | `geom_bar(position = "fill")` |
| `contour` | [`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html), [`geom_density_2d()`](https://ggplot2.tidyverse.org/reference/geom_density_2d.html) |
| `error_bar` | [`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html), [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html), [`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html), [`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html), [`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html), [`geom_ribbon()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html) as a band |
| `gantt` | [`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html), [`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html), [`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md) |
| `hexbin` | [`geom_hex()`](https://ggplot2.tidyverse.org/reference/geom_hex.html), [`stat_bin_2d()`](https://ggplot2.tidyverse.org/reference/geom_bin_2d.html) |
| `polygon` | [`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html) |
| `roc` | [`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md), [`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html), [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) of a [`yardstick::roc_curve()`](https://yardstick.tidymodels.org/reference/roc_curve.html) |
| `rug` | [`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html) |

#### Base R

| Layer type | Drawn by |
|----|----|
| `biplot` | [`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `box_stats` | [`bxp()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `conditional_density` | [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `correlogram` | [`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md), [`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md), [`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `cumulative_periodogram` | [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `dot` | [`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) (ungrouped) |
| `filled_contour` | [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `fourfold` | [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) (2x2 tables, `std = "ind.max"` / `"all.max"`) |
| `interaction` | [`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `lag` | [`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `lollipop` | `plot(type = "h")` |
| `mosaic` | [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) (two-way tables) |
| `pairs` | [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `qq` | [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `qqline` | [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `radar` | [`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `residual` | [`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) (two-way tables) |
| `spectral_density` | [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `spine` | [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `stacked_normalized_bar` | [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of proportions |
| `strip` | [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `subseries` | [`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `termplot` | [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) |
| `violin` | [`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html) |
| `word_cloud` | [`wordcloud::wordcloud()`](https://rdrr.io/pkg/wordcloud/man/wordcloud.html) |

#### lattice

Every chart maidr reads from lattice is experimental, including those
read as a layer type that is stable for ggplot2 and Base R: a
[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) is emitted
as the same `bar` layer as
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md), but
reading what lattice drew, panel by panel and group by group, is new.

| Layer type | Drawn by |
|----|----|
| `bar` | [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) without `groups`, [`histogram()`](https://rdrr.io/pkg/lattice/man/histogram.html) of a factor with one bar per level |
| `dodged_bar` | [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) with `groups` |
| `stacked_bar` | [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) with `groups` and `stack = TRUE`, [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a table or matrix |
| `hist` | [`histogram()`](https://rdrr.io/pkg/lattice/man/histogram.html) |
| `point` | [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html), [`qq()`](https://rdrr.io/pkg/lattice/man/qq.html), [`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) with several values on a level |
| `line` | `xyplot(type = "l")` and the lines of `"b"`, `"o"` and `"a"`, [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a time series, and the same `type`s on [`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) and [`qq()`](https://rdrr.io/pkg/lattice/man/qq.html) |
| `step` | `xyplot(type = "s")`, `xyplot(type = "S")` |
| `box` | [`bwplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) |
| `heat` | [`levelplot()`](https://rdrr.io/pkg/lattice/man/levelplot.html), `contourplot(region = TRUE)` |
| `contour` | [`contourplot()`](https://rdrr.io/pkg/lattice/man/levelplot.html), `levelplot(contour = TRUE)` |
| `smooth` | [`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html), and [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) and [`qq()`](https://rdrr.io/pkg/lattice/man/qq.html) with `type = "r"`, `"smooth"` or `"spline"` on numeric axes |
| `dot` | [`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) with one value per level |
| `lollipop` | `xyplot(type = "h")`, and `type = "h"` on [`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), [`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) and [`qq()`](https://rdrr.io/pkg/lattice/man/qq.html) |

A conditioned chart (`y ~ x | g`) is read one panel at a time, each
panel a subplot, laid out as lattice lays them out; `groups` gives one
point layer per group, or one series per group on a line or curve – one
layer per group when the groups’ curves share no x value, since Up and
Down only move between series that meet at the x being read. A chart
laid out over several pages is read from its first page, with a warning.
What the reading does not cover is shown as a static image:
[`cloud()`](https://rdrr.io/pkg/lattice/man/cloud.html),
[`wireframe()`](https://rdrr.io/pkg/lattice/man/cloud.html),
[`splom()`](https://rdrr.io/pkg/lattice/man/splom.html),
[`parallelplot()`](https://rdrr.io/pkg/lattice/man/splom.html), a panel
function of your own or one such as `panel.violin`,
`levelplot(useRaster = TRUE)`, latticeExtra layers and compositions, a
fit (`type = "r"`, `"smooth"` or `"spline"`) over a factor axis, as on a
[`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) or
[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html), and a panel
that fails to draw.

The split is the diff of each factory’s `get_supported_types()` against
`8de0e98`, the last commit on `main` before
[\#137](https://github.com/xability/r-maidr/issues/137) was filed. The
lattice factory came later, so every type it reads is experimental.
`tests/testthat/test-plot-type-stability.R` checks all three factories —
ggplot2, Base R and lattice — and fails if a type one of them supports
appears in neither the stable tables nor its experimental table, so a
new layer type has to be placed deliberately rather than inherit either
promise by being forgotten.

The [JavaScript core](https://maidr.ai/) and the [Python
binding](https://py.maidr.ai/) make the same distinction over their own
type lists, with the same boundary and for the same reason, and mark
their docs the same way: see the JavaScript core’s [trace type
stability](https://maidr.ai/docs/SCHEMA.html#trace-type-stability) and
the Python binding’s [stability
page](https://py.maidr.ai/stability.html).

See the [examples gallery](https://r.maidr.ai/articles/examples.html)
for a worked example of each plot type.

## Accessibility features

- **Keyboard navigation** - explore data points using arrow keys
- **Screen reader support** - full ARIA labels and live announcements
- **Sonification** - hear data patterns through sound
- **Text descriptions** - automatic statistical summaries

The keys a reader needs first, the same on every page of this
documentation:

| Key | Action |
|----|----|
| **Tab** | Focus the chart; **Shift + Tab** leaves it |
| **Left / Right** | Move between data points |
| **Up / Down** | Move between series, stacked segments, heat map rows or box plot sections, on a chart that has them |
| **Page Up / Page Down** | Switch between the layers of a chart that has several |
| **B** | Toggle braille mode |
| **T** | Toggle text mode |
| **S** | Toggle sonification |
| **R** | Toggle review mode |
| **C** | Toggle high contrast mode |
| **L**, then **X**, **Y** or **T** | Announce the x axis label, the y axis label or the title |
| **Space** | Repeat the current sound |
| **Ctrl + /** (**Cmd + /** on macOS) | Show or hide the full keyboard shortcut help |

Every other shortcut, including autoplay, jumping to the ends, the
command palette, settings and the AI chat, is on the [MAIDR controls
reference](https://maidr.ai/docs/CONTROLS.html).

## Offline support

By default, [`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) use the
bundled maidr.js library, so the result works offline.
[`save_html()`](https://r.maidr.ai/reference/save_html.md) writes the
library to a `lib/` folder beside the file, and the two have to be
shared together: zip the folder that holds both, or copy both. An
`.html` sent on its own loads no maidr.js and shows a plain,
inaccessible chart. A knitted R Markdown or Quarto page loads the
bundled maidr.js once for all its charts, from its `_files` folder or
embedded in it when it is `self_contained` / uses `embed-resources`, so
it works offline wherever it was rendered. Widgets, Shiny apps, and the
few knitted outputs that keep a chart in an iframe (an HTML fragment,
pagedown) auto-detect internet availability and use the CDN when online.
A page holding a widget rendered online also carries its own copy of
maidr.js, which its charts fall back on when the CDN cannot be reached,
so a `self_contained` / `embed-resources` page works offline too. Use
the `use_cdn` parameter for explicit control:

``` r

# Force CDN: one self-contained file, needs internet whenever it is viewed
show(p, use_cdn = TRUE)
save_html(p, "plot.html", use_cdn = TRUE)

# Force bundled files: works offline, lib/ folder beside the saved file
show(p, use_cdn = FALSE)
save_html(p, "plot.html", use_cdn = FALSE)
```

The CDN paths load the **latest published maidr.js**, not the copy
bundled with this package, as the Python binding does. The first CDN
document in an R session asks jsDelivr (then the npm registry) which
version that is, within 3 seconds, and every document in the session
names that version. If the lookup cannot be made it costs no error: the
document names the bundled version instead, the copy `use_cdn = FALSE`
would serve. Pin a version when a document has to load the same maidr.js
whenever it is opened:

``` r

options(maidr.cdn_version = "bundled")  # the bundled version, no lookup
options(maidr.cdn_version = "4.9.0")    # a particular release
```

or set `MAIDR_CDN_VERSION` in the environment. `use_cdn = FALSE` never
makes that lookup. See
[`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

Two things still reach the network from an offline document, and only
when a reader uses them. One is a language other than English. maidr.js
reads charts in English on its own and fetches Korean, Japanese,
Chinese, Spanish, German, French, Italian or Hindi as a small pack from
beside itself. This package does not bundle the packs, which would add
0.8 MB against CRAN’s size limit, so a `use_cdn = FALSE` document points
maidr.js at the packs of the bundled version on jsDelivr: a reader whose
language is not English hears it when online, and English when not.
Serve the packs yourself, or turn this off:

``` r

options(maidr.locale_base_url = "https://example.org/maidr/")  # your own copy
options(maidr.locale_base_url = FALSE)  # never fetch a pack: English only
```

The other is connecting a [DotPad tactile
display](https://maidr.ai/docs/TACTILE_DISPLAY.html). maidr.js does not
bundle the DotPad SDK, whose braille engine is a 14 MB liblouis build,
and imports the vendor’s copy from jsDelivr the first time a DotPad is
connected. Rendering, sonification and braille work offline regardless.
To keep the DotPad offline too, download the pinned SDK once and every
`use_cdn = FALSE` document carries it in its `lib/` folder:

``` r

maidr_download_dotpad_sdk()          # ~14 MB, once, into a per-user cache
save_html(p, "plot.html", use_cdn = FALSE)   # lib/dotpad-sdk-<version>/ beside it
```

A page served from elsewhere, or a knitted R Markdown or Quarto
document, which does not carry the downloaded copy, names its copy by
URL instead, through options or the environment variables of the same
names:

``` r

options(
  maidr.dotpad_sdk_url = "https://intranet.example/dotpad/DotPadSDK-3.0.3.js",
  maidr.dotpad_asset_base_url = "https://intranet.example/dotpad/lib/"
)
# or: Sys.setenv(MAIDR_DOTPAD_SDK_URL = "...", MAIDR_DOTPAD_ASSET_BASE_URL = "...")
```

Every document maidr produces then declares
`window.MAIDR_DOTPAD_SDK_URL` and `window.MAIDR_DOTPAD_ASSET_BASE_URL`
ahead of maidr.js. See
[`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

## Getting help

- Report bugs or request features at [GitHub
  Issues](https://github.com/xability/r-maidr/issues)
- Browse the [function
  reference](https://r.maidr.ai/reference/index.html), or run
  [`help(package = "maidr")`](https://r.maidr.ai/reference) offline

## Learning more

- [`vignette("getting-started", package = "maidr")`](https://r.maidr.ai/articles/getting-started.md)
  for an introduction
- The [examples gallery](https://r.maidr.ai/articles/examples.html) for
  supported visualizations
- [`vignette("shiny-integration", package = "maidr")`](https://r.maidr.ai/articles/shiny-integration.md)
  for Shiny apps
- The [maidr skill](https://github.com/xability/maidr-skill) for AI
  coding agents (Claude Code, Codex, Cursor, and others): once installed
  with `npx skills add xability/maidr-skill`, an agent that writes
  ggplot2 or base R plotting code routes the result through this package
  so the chart comes out accessible

## Related projects

maidr for R is one of three MAIDR packages, all developed by the
(x)Ability Design Lab at the University of Illinois Urbana-Champaign:

- [MAIDR JavaScript core](https://maidr.ai/), the TypeScript engine (npm
  package `maidr`) that renders every accessible chart, including the
  ones this package produces.
- [py-maidr for Python](https://py.maidr.ai/), the Python binding for
  matplotlib, seaborn, Plotly and Altair (PyPI package `maidr`).
- [maidr for R](https://r.maidr.ai/), this package, for ggplot2 and Base
  R graphics, with experimental lattice support (CRAN package `maidr`;
  source at [xability/r-maidr](https://github.com/xability/r-maidr)).

## Citation

If you use maidr in research, please cite the MAIDR papers:

- Seo, J., Xia, Y., Lee, B., Mccurry, S., & Yam, Y. J. (2024). MAIDR:
  Making Statistical Visualizations Accessible with Multimodal Data
  Representation. In Proceedings of the CHI Conference on Human Factors
  in Computing Systems (CHI ’24). ACM.
  <https://doi.org/10.1145/3613904.3642730>
- Seo, J., O’Modhrain, S., Xia, Y., Kamath, S., Lee, B., &
  Coughlan, J. M. (2024). Designing Born-Accessible Courses in Data
  Science and Visualization: Challenges and Opportunities of a Remote
  Curriculum Taught by Blind Instructors to Blind Students. In EuroVis
  2024 - Education Papers. The Eurographics Association.
  <https://doi.org/10.2312/eved.20241053>

`citation("maidr")` prints both, plus an entry for the package itself,
in text and BibTeX form.
