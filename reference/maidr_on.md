# Enable MAIDR Plot Interception

Turns on the accessible rendering of ggplot2, lattice and Base R plots.
It is on after [`library(maidr)`](https://github.com/xability/r-maidr):
`maidr_on()` is needed only to turn it back on after
[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md).

## Usage

``` r
maidr_on()
```

## Value

Invisible TRUE on success

## Details

Interception is on by default after
[`library(maidr)`](https://github.com/xability/r-maidr): printing a
ggplot2 or lattice object opens it in the MAIDR viewer, and Base R
plotting calls are recorded until
[`show()`](https://r.maidr.ai/reference/show.md) is called. lattice is
reached through its own hook, `lattice.options(print.function = )`,
which maidr sets once lattice's namespace is loaded; a print function
set before is kept, and draws the prints maidr leaves to lattice.

In an R Markdown or Quarto document,
[`library(maidr)`](https://github.com/xability/r-maidr) is enough:
loading maidr during the knit, or else the first chart the document
draws, installs the knitr hooks that make every plot of it an accessible
chart, in each render of a session. So any document rendered in a
session where maidr is loaded, even only its namespace (as a package
that imports maidr loads it), gets charts, whether or not it loads maidr
itself; `options(maidr.auto_show = FALSE)` before the render prevents
that. In a document, `maidr_on()` installs the hooks at once.

In HTML output the charts are part of the page, which loads maidr.js
once for all of them, and the static figures of a chunk are recorded
with svglite rather than knitr's default png (`maidr.knitr_dev` in
[maidr-options](https://r.maidr.ai/reference/maidr-options.md) turns
that off). A chunk can draw several charts – `print(p)` in a loop,
several Base R charts – and each takes the place of its own figure; a
figure maidr cannot read as one chart stays knitr's image. HTML that
cannot hold a chart in the page, such as an HTML fragment or pagedown,
shows each chart in a frame of its own. In PDF, Word, Markdown, EPUB or
xaringan output the plots are knitr's figures, as without maidr. A chart
a document returns or prints never opens the viewer; an explicit
[`show()`](https://r.maidr.ai/reference/show.md) still does, during the
render, and puts nothing in the page.

A chart is drawn at its chunk's `fig.width` and `fig.height`, in inches,
as knitr draws the chunk's figures: `fig.asp` and `fig.dim` set them as
they do for a figure, and so do R Markdown's `fig_width` and
`fig_height` and Quarto's `fig-width` and `fig-height`. Its SVG is 72
pixels to the inch. `html_document` and Quarto's HTML formats draw
figures at 7 x 5 in, maidr's own size outside a document. A format with
a figure size of its own draws its charts at that size:
[`rmarkdown::html_vignette`](https://pkgs.rstudio.com/rmarkdown/reference/html_vignette.html)
at 3 x 3 in, small enough that a Base R chart shows fewer tick labels,
ioslides at 7.5 x 4.5 in, slidy at 8 x 6 in and
[`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html) on its own at
7 x 7 in. Set `fig.width` and `fig.height` to draw a chart at another
size.

A candlestick chart is drawn at least 12 x 6 in. A chunk that sets a
smaller size of its own is told so in a message (see
[`show()`](https://r.maidr.ai/reference/show.md)): among the chunk's
messages for a ggplot2 chart, and on the console for a Base R
[`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
chart, which maidr reads once the chunk has run. The document's figure
size, which the format, its YAML or `knitr::opts_chunk$set()` sets for
every chunk, was not asked of a candlestick chart, which is drawn larger
than it without a message.

maidr draws a Base R chart again from its recorded calls, with the
margins and text size its chunk's
[`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls set
(`mar`, `mai`, `oma`, `omi`, `mex` and `cex`), so it fits where R drew
it. A chart R drew in its chunk with settings maidr does not record – a
[`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) called by
name, as [`graphics::par()`](https://rdrr.io/r/graphics/par.html), or
another of its settings – can still be too small for its size in maidr.
Too small for the document's figure size, it is drawn larger, as one too
small for 7 x 5 in is outside a document (see
[`show()`](https://r.maidr.ai/reference/show.md)), and a message on the
console names the size. Too small for a size its chunk sets of its own,
it stays knitr's picture, with a warning naming the size.

Whether a chunk set its size is read from the size, not from where it
was set: a chunk that sets the document's own, `fig.width = 7` and
`fig.height = 5` in `html_document`, is taken to set none, for a
candlestick chart and a Base R chart alike.

The size is the room the chart is laid out in, not what a reader hears:
its data, titles and axes are the same at every size, though a lattice
chart conditioned on one variable with no `layout =` arranges its
panels, and the grid a reader moves through, for it (see
[`show()`](https://r.maidr.ai/reference/show.md)). Nor is it the width
the chart is shown at, which `out.width` sets: a chart shrinks to fit a
page narrower than itself, keeping its shape. `dpi` is not read.

A chart's caption, in R Markdown and bookdown, is plain text: Markdown,
maths and `\@ref()` in `fig.cap` are shown as written, and a bookdown
text reference (`fig.cap = "(ref:label)"`) brings them in.
`fig.show = "animate"` stays knitr's animation.

A chunk cached with `cache = TRUE` brings its charts back from knitr's
cache. One cached with `cache = 1` or `cache = 2` shows them only when
its code runs: rendered again from the cache, its figures are knitr's
static images, since the charts they were drawn from are not cached with
them.

## See also

[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) to disable
MAIDR rendering

## Examples

``` r
# \donttest{
library(maidr)

# Enable interception (on by default after library(maidr))
maidr_on()

# Now all plots render as accessible MAIDR charts
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl))) +
  geom_bar()

barplot(table(mtcars$cyl))

# }
```
