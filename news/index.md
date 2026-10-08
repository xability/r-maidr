# Changelog

## maidr (development version)

### New Features

#### Chart size

- A chart’s size can be set, in inches as
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
  and knitr’s `fig.width` take one:
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) take
  `width` and `height`, and
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) takes
  `fig_width` and `fig_height`, while
  [`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md)’s
  `width` and `height` still size the output on the page. The SVG is 72
  pixels to the inch. Every chart used to be drawn at 7 x 5 in whatever
  was asked, and a `width` given to
  [`show()`](https://r.maidr.ai/reference/show.md) or
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) was
  silently ignored, except by the static picture of a chart maidr could
  not read. Unset, the size is still 7 x 5 in
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- In R Markdown and Quarto a chart is drawn at its chunk’s `fig.width`
  and `fig.height`, so `fig.asp`, `fig.dim`, YAML `fig_width` and
  `fig_height` and Quarto’s `fig-width` and `fig-height` set it too.
  `html_document` and Quarto’s HTML draw figures at 7 x 5 in, so their
  charts keep the size they had. A format with a figure size of its own
  now draws its charts at it: `html_vignette` at 3 x 3 in, where a Base
  R chart shows fewer tick labels, ioslides at 7.5 x 4.5 in, slidy at 8
  x 6 in ([\#355](https://github.com/xability/r-maidr/issues/355)).
- A candlestick chart is still never drawn smaller than 12 x 6 in, and a
  smaller size asked for is enlarged with a message naming the size
  used. In a document that is a size the chunk sets itself, and the
  message is among the chunk’s own for a ggplot2 chart and on the
  console for Base R’s
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md);
  drawn larger than the document’s figure size, a candlestick chart says
  nothing, as before
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- A size that is not one positive number is an error naming the
  argument, and so is one over 50 in, which
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
  refuses too: the error says the size is in inches, not the pixels
  [`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md)
  takes. A Base R chart too small for its margins and text at a size
  asked for, which R cannot draw at that size either (“figure margins
  too large”), is an error naming the size and R’s reason rather than an
  empty chart, or a blank picture of a chart maidr cannot read
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- A Base R chart too small for a size no one asked for – maidr’s own 7 x
  5 in, or in a document the figure size every chunk that sets none is
  drawn at – is drawn larger, with a message naming the size. It is
  drawn on the 7 x 7 in page maidr laid every Base R chart out on before
  it drew one at its size, as a `par(mfrow)` grid of five rows was.
  Where that is too small too, it is drawn on the smallest larger page
  that leaves each of its plots a sixth of an inch, 12 px, each way,
  each side grown in whole inches only as far as it needs: 7 x 9 in for
  six rows, 12 x 5 in for twelve columns. The picture of a chart maidr
  cannot read, such as a grid of
  [`persp()`](https://r.maidr.ai/reference/base-r-wrappers.md) plots, is
  drawn larger in the same way
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- The size changes how a chart is laid out and nothing a reader hears:
  the data, titles and axis labels are the same at every size, apart
  from the page coordinates a violin’s density curve carries for its
  highlight. A lattice chart conditioned on one variable with no
  `layout =` gets the columns lattice gives a page of its shape, and its
  subplot grid, the order a reader moves through its panels in, with
  them: two panels are 1 x 2 at 7 x 5 in and 2 x 1 at 5 x 8 in
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- `show(as_widget = TRUE)` no longer passes `width` and `height` on to
  the widget as its CSS size, which it did through `...` without saying
  so: they are the size the chart is drawn at, in inches, as everywhere
  in [`show()`](https://r.maidr.ai/reference/show.md). A CSS size such
  as `"300px"` is now an error that says so. Set the widget’s own size
  on the widget [`show()`](https://r.maidr.ai/reference/show.md)
  returns, `widget$width <- "300px"`
  ([\#355](https://github.com/xability/r-maidr/issues/355)).

#### R Markdown and Quarto

- [`library(maidr)`](https://github.com/xability/r-maidr) is all an R
  Markdown or Quarto document needs: every plot it draws, with
  ‘ggplot2’, ‘lattice’ or Base R, becomes an accessible chart, without
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) in a setup
  chunk ([\#352](https://github.com/xability/r-maidr/issues/352)). maidr
  installs its ‘knitr’ hooks into the knit when the document loads it,
  or at the first chart the document draws, and does so again in every
  render of a session, so a second
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html),
  and `R CMD build`, which renders every vignette in one process, get
  charts too. [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md)
  still works, and
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) in a chunk
  knits the chunks after it as they would be without maidr; it lasts for
  the R session, so a document that turns maidr off, and every document
  rendered after it in the session, stays off until
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md). A document
  rendered in a session where maidr is loaded, even only its namespace,
  as by a package that imports it, gets charts whether or not it loads
  maidr itself; `options(maidr.auto_show = FALSE)` prevents that.
  maidr’s startup message is no longer written into a document.
- In HTML output a chart is now part of the page, an `<svg>` in a raw
  HTML block, where it used to be an iframe that loaded maidr.js for
  itself. The page loads maidr.js once however many charts it has, from
  its `_files` folder or embedded in a `self_contained` /
  `embed-resources` page, where a document rendered offline used to
  carry a copy of the bundle in every chart’s frame. Every id of a chart
  is given a prefix of its own, so charts sharing a page never reach
  into one another. This covers `html_document` and the formats built on
  it, ‘bookdown’, Quarto (HTML, reveal.js, dashboards and websites),
  ‘revealjs’, ioslides, slidy and ‘flexdashboard’. Before maidr.js has
  loaded, and if it never does, a chart is an image named by `fig.alt`,
  `fig.cap`, its title or its kind; once it has, `fig.alt` and the
  caption describe it. maidr’s help, settings and chat open in the page
  at their own size, on a Bootstrap 3 page (`html_document`‘s default
  theme) as on any other, and within the window in a reveal.js deck.
  Once a page shows a maidr chart, maidr.js also reads the plain
  ’plotly’ widgets on it, which become maidr charts with a tab stop of
  their own, as they did on a page holding a
  [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md).
  An HTML fragment, ‘pagedown’ and `.Rhtml` keep each chart in an iframe
  of its own, as does a chart that cannot be shown inline, with a
  warning. In EPUB and ‘xaringan’ output, as in PDF, Word and Markdown,
  the plots are knitr’s figures, where a document that called
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) used to stop
  with an error (EPUB) or show each chart’s iframe as text on its slide
  (‘xaringan’).
- In HTML output ‘knitr’ records a chunk’s figures with ‘svglite’
  instead of its default png, so the figures that stay images are vector
  images too. Only the default is replaced: a device a chunk names, a
  document device other than png, and the device of a cached chunk, of
  an animation and of a chunk that crops its figures or hands them to
  `fig.process` are kept. `options(maidr.knitr_dev = FALSE)` keeps png
  for every chunk, for a document whose `dev: png` is a choice, which
  cannot be told from the default; see
  [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md). A
  ‘flexdashboard’ gets SVG figures too, with no separate copy for
  phones.
- A chunk can draw several charts. A ggplot2 or lattice chart printed
  with [`print()`](https://rdrr.io/r/base/print.html), in a loop or a
  function, used to stay a static image, and the Base R charts of a
  chunk all became its first figure. Now each chart takes the place of
  its own figure, so `fig.cap`, `fig.alt`, `fig.keep`, `fig.show`, the
  `fig:label-1`, `fig:label-2` labels of ‘bookdown’ and Quarto’s `@fig-`
  references apply to it as they apply to the figure, and charts held
  with `fig.show = "hold"` at an `out.width` sit side by side, as
  knitr’s images do. A chart a chunk returns is one of its figures too,
  numbered and captioned with the others, and `results = "hide"` no
  longer drops it. A figure that is not one chart maidr can read – two
  charts on one page, a chart something was drawn over, a grid drawing,
  a chart type maidr does not read – stays knitr’s image rather than
  risk showing the wrong chart. A chunk cached with `cache = TRUE`
  brings its charts back; one cached with `cache = 1` or `cache = 2`
  brings back static figures, and `fig.show = "animate"` stays knitr’s
  animation. In R Markdown and bookdown a chart’s caption is plain text,
  Markdown, maths and `\@ref()` in it shown as written; a bookdown text
  reference, `fig.cap = "(ref:label)"`, brings them in.
- The keys of the page around a chart no longer act while the chart has
  the focus. A chart in a frame had its keys to itself; inline, the
  arrow keys, Space and the other shortcuts of a reveal.js deck, the
  gitbook format of ‘bookdown’, a Quarto website’s search, an ioslides
  or slidy deck, a ‘flexdashboard’ storyboard and the `/` search key of
  a ‘pkgdown’ site would have acted on the keys maidr reads. Tab moves
  into a chart and Shift+Tab out of it, after which the page’s keys work
  again. The focus ring stays visible on a page whose CSS removes
  outlines, and in forced colours.

#### lattice

- Charts drawn by ‘lattice’ are now read
  ([\#333](https://github.com/xability/r-maidr/issues/333)).
  [`show()`](https://r.maidr.ai/reference/show.md),
  [`save_html()`](https://r.maidr.ai/reference/save_html.md),
  `show(as_widget = TRUE)`,
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) in
  Shiny, and R Markdown and Quarto take a trellis object, and printing
  one at the console opens it in the maidr viewer, as printing a ggplot2
  object does. Every lattice reading is experimental: none has been
  through a user study, and each may change without a deprecation
  period. ‘lattice’ is now in Suggests, as is ‘latticeExtra’, which only
  the tests use.

- [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) is emitted
  as a `bar` layer, as `dodged_bar` with `groups`, and as `stacked_bar`
  with `stack = TRUE`, the default for a table or a matrix;
  [`histogram()`](https://rdrr.io/pkg/lattice/man/histogram.html) as
  `hist`; [`bwplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) as
  `box`; [`levelplot()`](https://rdrr.io/pkg/lattice/man/levelplot.html)
  as `heat`; and
  [`contourplot()`](https://rdrr.io/pkg/lattice/man/levelplot.html) and
  `levelplot(contour = TRUE)` as `contour`.
  [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) is read by
  its `type`: its points as `point`, one layer per group, named after
  it; `"l"` as `line` and `"s"` or `"S"` as `step`, one series per
  group; `"h"` as `lollipop`; and `"r"`, `"smooth"` and `"spline"` as a
  `smooth` curve.
  [`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html) is
  read as `smooth`, one curve per group;
  [`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) as `dot`,
  or as points when a level holds several values; and
  [`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html),
  [`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) and
  [`qq()`](https://rdrr.io/pkg/lattice/man/qq.html) as `point`, with the
  lines, spikes, fits and averages their `type` adds read as
  [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html)’s are – save
  a fit over a factor axis, below – and a line through the levels of a
  horizontal dot or strip plot read level by level, as its vertical
  transpose is. A
  [`histogram()`](https://rdrr.io/pkg/lattice/man/histogram.html) of a
  factor, one bar per level, is read as a `bar` layer named by its
  levels. [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a
  time series is read as a `line`, in a panel per series or superposed,
  its values named after the series rather than lattice’s own `x`. Every
  layer names the marks it reads, so each point, bar, bin, dot and
  spike, each box, each heat map cell and each line, curve and contour
  is highlighted as it is read.

- The groups of a line, step or smooth layer that share no x value – the
  densities of a grouped
  [`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html), say
  – are read as a layer each, named after the group, which Page Up and
  Page Down reach. Kept together, only the first could be reached: the
  frontend moves Up and Down only between series that meet at the x
  being read. Where a panel holds layers of more than one kind, a
  group’s layers also say what they are, as in “4 (point)” and “4
  (line)”, and two curves of one kind say which curve each is: “4
  (line)” and “4 (average)”, “4 (loess)” and “4 (spline)”, or “line” and
  “average” where the groups are read together.

- A conditioned chart (`y ~ x | g`) is read one panel at a time, each
  panel a subplot titled by its strip and laid out as lattice lays the
  panels out; a strip made by
  [`strip.custom()`](https://rdrr.io/pkg/lattice/man/strip.default.html)
  – its `factor.levels`, and the variable’s name where
  `strip.names = TRUE` draws it – and an `auto.key`’s `text` name the
  panels and groups as they show them. A chart laid out over several
  pages is read from its first page – or the page a `packet.panel` picks
  – with a warning that names `layout =` as the way to fit every panel
  on one, and so is its image when it cannot be read. `main` is the
  chart’s title and `sub` its subtitle, and an axis is named by `xlab`
  or `ylab`, or by the variable lattice would name it after.

- A chart the reading does not cover is shown as a static image rather
  than read wrongly:
  [`cloud()`](https://rdrr.io/pkg/lattice/man/cloud.html),
  [`wireframe()`](https://rdrr.io/pkg/lattice/man/cloud.html),
  [`splom()`](https://rdrr.io/pkg/lattice/man/splom.html),
  [`parallelplot()`](https://rdrr.io/pkg/lattice/man/splom.html), a
  panel function of the user’s own or one such as `panel.violin`,
  `levelplot(useRaster = TRUE)`, latticeExtra layers and compositions
  (`+ layer()`, [`c()`](https://rdrr.io/r/base/c.html),
  `doubleYScale()`), a fit (`type = "r"`, `"smooth"` or `"spline"`) over
  a factor axis, which lattice draws between the levels, where the axis
  names nothing, and a panel that fails to draw. Printed at the console,
  such a chart is drawn by lattice as before.

- Printing goes through lattice’s own `print.function` option, which
  maidr sets once ‘lattice’ is loaded and
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) restores. A
  print that shares its page with other charts (`split`, `position`,
  `more = TRUE`, `newpage = FALSE`, given to
  [`print()`](https://rdrr.io/r/base/print.html) or carried in the
  chart’s `plot.args`), a print into a file device such as
  [`pdf()`](https://rdrr.io/r/grDevices/pdf.html) or
  [`png()`](https://rdrr.io/r/grDevices/png.html), a print inside Shiny,
  and `plot(p)` are drawn by lattice as before. A chart lattice draws at
  the console while a Base R chart waits for
  [`show()`](https://r.maidr.ai/reference/show.md) goes on a screen,
  with the theme set by
  [`trellis.par.set()`](https://rdrr.io/pkg/lattice/man/trellis.par.get.html),
  not onto the hidden device maidr records that chart on. In R Markdown
  and Quarto a chart the chunk returns and one it draws with `print(p)`
  are both made accessible, each in place of its own figure.
  `options(maidr.lattice = FALSE)` leaves lattice printing alone, and
  setting it back to `TRUE` takes effect at the next print; see
  [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).
  Saving, showing or knitting a chart leaves lattice’s own record of the
  chart it drew last – the one
  [`trellis.focus()`](https://rdrr.io/pkg/lattice/man/interaction.html)
  and
  [`trellis.last.object()`](https://rdrr.io/pkg/lattice/man/update.trellis.html)
  act on – as it was.

- An `xyplot(precision ~ recall, type = "l")` – or one whose axes are
  otherwise titled `Recall` and `Precision` – of values that are all
  fractions of one is emitted as a `pr_curve` layer, one curve per
  group, as a ggplot2 line of `recall` against `precision` is: a reader
  hears each point against the curve’s average precision and the best-F1
  point in the description, where a line said the rates and nothing
  else. Any other line keeps its reading. Needs maidr.js 4.14.0 or
  later, which this release bundles.

#### webR

- [`show()`](https://r.maidr.ai/reference/show.md) works under webR,
  where it used to stop at
  [`utils::browseURL()`](https://rdrr.io/r/utils/browseURL.html). The
  chart is added to the page the R session runs in, as an iframe in the
  element with id `maidr-output`, or at the end of `<body>` when there
  is none; the frame is sized to the chart and Shift+Tab leaves it, as
  from any other maidr frame. A page can take the document itself by
  defining `globalThis.maidrWebRShow(html)`, and R code can by setting
  `options(maidr.webr_display = function(html) ...)`; either is used
  instead of the iframe. R runs in a web worker, so reaching the page
  needs webR’s `SharedArrayBuffer` or service worker channel, and a page
  that allows `unsafe-eval`. Where the page cannot be reached,
  [`show()`](https://r.maidr.ai/reference/show.md) says why and saves
  the document to a temporary file; take it from R with the option
  instead, which works over every channel. webR’s own repository carries
  an older maidr until a CRAN release containing this is picked up by
  it; install the development version from r-universe
  (`xability.r-universe.dev`), which builds it for webR, or build it
  with `rwasm::add_pkg()`. See
  [`vignette("webr")`](https://r.maidr.ai/articles/webr.md). A new CI
  job builds maidr for webR and, in a browser, installs it from that
  build and calls [`show()`](https://r.maidr.ai/reference/show.md). A
  ggplot2 bar chart, a faceted scatter plot, a patchwork, lattice
  [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) and
  [`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html), and Base
  R [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and a
  two-panel layout each become a document in webR that a keyboard reads
  in the page; the ggplot2 bar chart has been through the whole path in
  a browser. A plotly, highcharter or echarts4r widget given to
  [`show()`](https://r.maidr.ai/reference/show.md) is made accessible
  with
  [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
  and shown the same way; its document carries the chart library, three
  to six megabytes. A plotly bar chart has been through the whole path
  in a browser. `show(as_widget = TRUE)` and the Shiny functions have
  not been tried.

#### Base R

- Added directed graph support: igraph’s own
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
  directed graph is emitted as a `directed_graph` layer, so a reader
  walks the graph node by node and hears what feeds each node and what
  it feeds, with that node’s circle outlined. The nodes and edges are
  read from the igraph object, and each vertex’s own attributes are
  announced with it. It used to be emitted as a scatter with no points
  in it; an undirected graph, or one whose vertices are not all circles,
  is now shown as a picture instead. Needs maidr.js 4.14.0 or later,
  which this release bundles.
- A `plot(recall, precision, type = "l")` or `type = "s"` – or any line
  or staircase whose axes are titled `Recall` and `Precision` – of
  values that are all fractions of one is emitted as a `pr_curve` layer,
  as a ggplot2 line of `recall` against `precision` is, rather than a
  line or a step. An
  [`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md) drawn
  over it, such as the chance level, stays a line. Needs maidr.js 4.14.0
  or later, which this release bundles.
- [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a ROCR
  `performance` object is read from the object. ROCR’s plot method draws
  its curve from inside ROCR’s namespace, where maidr records nothing,
  so the chart used to be emitted as a scatter with no points in it. A
  precision-recall curve, `plot(performance(pred, "prec", "rec"))`,
  which ROCR titles `Recall` and `Precision`, is now a `pr_curve` layer,
  each point announced with the cutoff it was scored at, from the
  object’s `alpha.values`; any other measure ROCR plots, a ROC curve’s
  rates among them, is a line. A cross-validated object of several runs
  is one curve per run. A plot drawn with `avg`, `colorize = TRUE`,
  `downsampling`, `add = TRUE` or a `type` other than `"l"` is shown as
  a picture. ROCR exports an S4 generic for
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md), so
  attached after maidr it masks maidr’s
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and no
  bare [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
  is recorded at all: attach ROCR before maidr, or call
  [`maidr::plot()`](https://r.maidr.ai/reference/base-r-wrappers.md).
  maidr now says so when ROCR is attached after it, and in the “No Base
  R plots detected” error.
- A
  [`wordcloud::wordcloud()`](https://rdrr.io/pkg/wordcloud/man/wordcloud.html)
  chart highlights the word being read: as the arrow keys move, the word
  announced is recoloured in the reader’s highlight colour. Each term is
  matched to the text R drew it as by its label, so the layout’s random
  order does not matter. A cloud with a term
  [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) could
  not fit on the page is read without a highlight rather than with
  highlights on the wrong words
  ([\#356](https://github.com/xability/r-maidr/issues/356)).

#### Monarch tactile display

- A chart’s frame now delegates WebHID as well as Web Bluetooth and Web
  Serial (`allow="bluetooth; serial; hid"`), so a Monarch in its Braille
  Terminal can draw an R chart inside a cross-origin frame, as a Dot Pad
  already could. Drawing on a Monarch also needs a maidr build that
  supports it.

#### ggplot2

- Added precision-recall curve support: a precision-recall curve is
  emitted as a `pr_curve` layer, one curve per classifier, so a reader
  hears each point’s recall and precision, its threshold and how far its
  precision sits above the share of positives, and the average precision
  of each curve and the point with the best F1 score in the description.
  [`maidr_pr_curve()`](https://r.maidr.ai/reference/maidr_pr_curve.md)
  declares one – it is
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  with a `threshold` aesthetic and `prevalence` and `ap` arguments – and
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  of a
  [`yardstick::pr_curve()`](https://yardstick.tidymodels.org/reference/pr_curve.html)
  is read as it stands, by the `recall` and `precision` it maps. The
  trace needs maidr.js 4.14.0 or later, which this release bundles; an
  older bundle keeps the line reading these charts had.
- Added percentile band support: ggdist’s `stat_lineribbon()`, and a
  `geom_lineribbon()` of a `median_qi()` summary, are emitted as a
  `percentile_band` layer, so a reader enters each x on the median and
  walks up and down through the quantiles, each announced with the band
  it bounds (“Middle 80% is 0.4 to 1.61”), and each band is outlined as
  it is read. The chart used to fall back to a static image, since
  ggdist’s geom was not read at all. Only a median with quantile
  intervals is read this way – a ribbon of width `w` spans the quantiles
  `(1 - w) / 2` and `(1 + w) / 2` – so a mean, a highest-density
  interval or several series in one layer keep the reading they had.
  Needs maidr.js 4.14.0 or later, which this release bundles.
- A `stat_summary(geom = "ribbon", fun.data = median_hilow)` band is now
  read as a `percentile_band` layer too: the stat computes the quantiles
  `(1 - w) / 2` and `(1 + w) / 2` around the median, `w` being
  `fun.args$conf.int` (0.95 unless set), so a reader enters each x on
  the median and hears the band as the share it covers (“Middle 50% is
  …”) where it used to hear two bare bounds of an error bar. A
  [`stat_summary()`](https://ggplot2.tidyverse.org/reference/stat_summary.html)
  line of the median (`fun = median`, or `fun.data = median_hilow`)
  drawn on the same rows is read as the band’s median and outlined with
  it, rather than a second line. Any other summary, a ribbon of several
  series or a flipped one, and a median line that sits on more than one
  band, keep the reading they had. A `median_hilow` point range or error
  bar stays an error bar: the band trace outlines one shape across every
  x, not one per
  24. Needs maidr.js 4.14.0 or later, which this release bundles.
- Added directed graph support: a
  [`ggraph::ggraph()`](https://ggraph.data-imaginist.com/reference/ggraph.html)
  drawing of a directed graph is emitted as a `directed_graph` layer, so
  a reader walks the graph node by node and hears what feeds each node,
  what it feeds, and where the graph branches and merges, with that
  node’s point outlined. The nodes and edges are read from the igraph
  object ggraph laid out, and each node’s own attributes are announced
  with it. The chart used to fall back to a static image, since ggraph’s
  edge geoms were not read. An undirected graph keeps the reading it
  had. Needs maidr.js 4.14.0 or later, which this release bundles.

#### plotly, highcharter and echarts4r widgets

- [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
  takes `percentile_bands`, which declares the fan charts an echarts4r
  chart draws – a median
  [`e_line()`](https://echarts4r.john-coene.com/reference/e_line.html)
  and, for each band, an
  [`e_area()`](https://echarts4r.john-coene.com/reference/e_area.html)
  of its width stacked on an invisible line at its lower edge – naming
  the median’s series, each band’s filled series and the quantiles of
  its edges. MAIDR then reads the fan as one `percentile_band` layer, as
  it reads ggdist’s lineribbon: a reader enters each x on the median and
  walks through the quantiles, and each band is outlined as it is read.
  ECharts carries nothing that says which quantiles a band’s edges are,
  so without the declaration the series stay a line and two areas. The
  levels are checked in R, with the rules maidr.js applies – fractions,
  every `lower` below 0.5 and every `upper` above it, the bands nested –
  and a series name the chart does not have is a warning. It is passed
  to the ECharts adapter’s `percentileBands` option, which maidr.js
  reads from 4.15.0; the maidr.js bundled with this release is 4.14.0,
  so the option takes effect with `use_cdn = TRUE` and is otherwise
  checked, then ignored with a warning, until the bundle is raised. Draw
  the fan over a category x axis: over a numeric one ECharts stacks the
  series on the x values, and draws no band.

### Performance

- The SVG export, the maidr-data payload and the ggplot2 heatmap grid
  now do their per-shape and per-point work in C++ through ‘Rcpp’, which
  is added to Imports and LinkingTo; the package now has compiled code.
  The output is byte for byte what it was. Measured with
  [`save_html()`](https://r.maidr.ai/reference/save_html.md): a 300 x
  300
  [`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  heatmap went from 65 s to 5.6 s – its cells were found by scanning
  every source row for every tile – a 100 x 100 one from 2.2 s to 0.7 s,
  a 50,000-point
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  from 2.7 s to 1.2 s, a 50,000-point
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  from 4.4 s to 3.5 s, and a 2,000-bar
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  from 3.5 s to 1.9 s
  ([\#343](https://github.com/xability/r-maidr/issues/343)).

### Bug Fixes

#### R Markdown and Quarto

- A Quarto document holding a chart made with
  [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
  renders again. Quarto copies every dependency of a page from disk, and
  stopped with “Dependency maidr-locale-config 1.0.0 is not disk-based”,
  or the same of `maidr-dotpad-config` when a DotPad SDK location is
  set. The two dependencies, which only write to the page’s `<head>`,
  now name the bundle’s directory without declaring any file in it
  ([\#352](https://github.com/xability/r-maidr/issues/352)).
- A Base R chart in an R Markdown or Quarto document is read from the
  chunk’s own graphics device. maidr read whichever device was current
  when ‘knitr’ wrote the figure, which is the chunk’s only when no other
  device is open: with a [`pdf()`](https://rdrr.io/r/grDevices/pdf.html)
  left open, or the IDE’s screen when the document is rendered from the
  console, a chunk’s Base R chart came out as a static image, and a
  chart drawn at the console and never shown could be shown in place of
  the figure of a chunk that drew no Base R chart
  ([\#352](https://github.com/xability/r-maidr/issues/352)).
- In Markdown output (`github_document`, `md_document`, a plain
  [`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html) of an
  `.Rmd`) a chart is drawn by its library as one of knitr’s figures. It
  used to be an iframe, which GitHub drops, and online ‘rmarkdown’
  stopped the render, refusing the HTML dependency the frame brought
  (“Functions that produce HTML output found in document targeting …”)
  ([\#352](https://github.com/xability/r-maidr/issues/352)).
- maidr’s dialogs, opened from a chart a knitted page shows inline (new
  in this version, above), are enlarged only by as much as maidr.js left
  their text short of the size it has on a page that leaves its root
  font size alone, which follows the reader’s default font size. On a
  page whose root is smaller – `html_document`‘s default theme, the
  gitbook format of ’bookdown’, ‘flexdashboard’ – they were zoomed by
  16px divided by the root’s size (1.6 on a 10px root), whatever size
  maidr.js had given their text and whatever the reader’s default, so a
  maidr.js that sizes its dialogs for such a page itself would have
  shown 22.4px body text under a 20px title. With the bundled maidr.js
  4.13.0 their body text is still 14px under a 20px title at a browser’s
  default font size
  ([\#354](https://github.com/xability/r-maidr/issues/354)).

#### ggplot2

- A layer that maps x or y in its own
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html) is read
  under the axis title,
  [`labs()`](https://ggplot2.tidyverse.org/reference/labs.html)
  included, as the chart shows it. The layer’s own mapping replaced the
  title outright, so
  `geom_histogram(aes(y = after_stat(density))) + labs(y = "Density")`
  was announced as “after_stat(density) is 0.07” while the axis said
  “Density”, and a one-layer `geom_col(aes(month, sales))` lost its
  [`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) titles
  to “month” and “sales”. A layer is now named for its own mapping only
  when another layer read beside it plots something else on that axis –
  `geom_col(aes(y = sales)) + geom_line(aes(y = target))` still reads
  “sales” and “target” – and then by the name ggplot2 gives it,
  “density” rather than “after_stat(density)”. Decoration maidr does not
  read, such as
  [`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
  and
  [`geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
  value labels, does not count as such a layer, nor does a
  [`stat_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  curve, so a density histogram with a normal curve over it reads
  “Density” on both. Layers read together as one entry – line layers
  merged into one multi-series layer, and the layers of a facet panel –
  are named by the axis title when they plot different things, rather
  than after the first of them
  ([\#349](https://github.com/xability/r-maidr/issues/349)).
- A point layer follows the same rule. It was always read under the axis
  title, so the points of
  `geom_col(aes(y = sales)) + geom_point(aes(y = target))` were
  announced as “sales”, and two
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  layers plotting `hp` and `qsec` both as “hp”. They now read “target”,
  and “hp” and “qsec”; so does a
  [`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  or
  [`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  that maps its own y beside a layer plotting something else. A constant
  in [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html) – the
  `y = 0` a lollipop’s stems start from, or `aes(x = "")` for a
  one-group strip chart – names no variable, so it neither names its
  layer (“0”) nor counts as another layer plotting something else; nor
  does a segment or curve drawn with an arrow. A category dodged or
  nudged by hand – `as.numeric(term) + 0.1`, or `factor(cyl)` beside
  `cyl` – is still that category
  ([\#349](https://github.com/xability/r-maidr/issues/349)).

#### Base R

- A Base R chart that draws random numbers is exported as it was drawn.
  maidr exports a chart by drawing the recorded call again, and drew it
  from whatever random state the session had by then: a
  [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) came
  out with its words turned and placed differently from the cloud on the
  reader’s screen, a `stripchart(method = "jitter")` with other jitter,
  and each again differently on every save. Each call now keeps the
  random state it started from and is drawn again from it. Exporting a
  chart also no longer moves the session’s random numbers on, which
  changed what a script’s
  [`set.seed()`](https://rdrr.io/r/base/Random.html) gave every call
  after it.
- A Base R chart is laid out on a page of the size it is drawn at. maidr
  drew it with
  [`ggplotify::as.grob()`](https://rdrr.io/pkg/ggplotify/man/as-grob.html),
  which lays every drawing out on a 7 x 7 in page of its own, and the
  chart was then stretched onto its 7 x 5 in: a legend’s lines ran into
  one another and the title sat half as far below the top edge as R puts
  it. The drawing is now made on a page of the chart’s own size, with
  the graphical parameters `as.grob()` sets, so at 7 x 7 in it is the
  drawing `as.grob()` made
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- A Base R chart is drawn with the margins and text size its
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls set –
  `mar`, `mai`, `oma`, `omi`, `mex` and `cex` – where maidr drew it with
  R’s own. A chart given small margins, as
  `par(mfrow = c(5, 1), mar = c(1, 2, 1, 1))` gives a grid R draws at 7
  x 5 in, was drawn with larger ones and its plots squeezed, and at a
  size asked for it was called too small to draw, though R drew it there
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- A Base R chart’s axes show the tick labels R shows. R’s
  [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) leaves out
  a label that would run into the one before it, but the drawing maidr
  makes of a Base R chart kept every label, so they ran together on a
  small chart or in the panels of a `par(mfrow)` grid: 10, 12 and 14 on
  a short y axis where R shows 10 and 14. The labels R leaves out are
  now left out too, measured as R measures them at the chart’s size
  ([\#355](https://github.com/xability/r-maidr/issues/355)).
- A Base R [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  page is drawn with the `widths`, `heights` and `respect` its call
  sets. maidr set the page up again from the matrix alone, so every
  column was as wide and every row as tall as the others: the first plot
  of `layout(matrix(1:2, 1), widths = c(3, 1))` took half the width,
  where R gives it three quarters, and the plot of a single cell, as in
  `layout(matrix(1), widths = lcm(5), heights = lcm(5))`, filled the
  page. Each plot is now drawn where R draws it – with
  [`lcm()`](https://rdrr.io/r/graphics/layout.html) sizes, a `respect`
  matrix, cells that span several rows or columns, empty cells, and in
  the one cell of each layout set up over a page of plots, a grid’s
  among them, to draw a plot or a legend’s
  [`plot.new()`](https://rdrr.io/r/graphics/frame.html) panel over them,
  or in the one panel of such a layout over several cells given
  `widths`, `heights` or `respect` – and shows the tick labels R shows
  at its size. A size asked for now stops when R cannot draw the page at
  it, and a size no one asked for is enlarged until every plot, the
  smallest included, has room. When it is the cells the call sized with
  [`lcm()`](https://rdrr.io/r/graphics/layout.html) that do not fit on
  the page, the error and the message name them. The matrix is the
  argument R takes for it, written by name after the sizes, as in
  `layout(widths = c(3, 1), mat = m)`, or without a name after a size
  written with one, as in `layout(widths = c(3, 1), m)`. maidr took the
  widths for the matrix: it warned that it could not draw the page, drew
  none of it, and read the plots in a grid of the wrong shape, one of
  them missing. A size left out with an empty argument, as in
  `layout(m, , c(1, 3))`, which leaves out the widths, no longer loses
  the page either: maidr drew only the first plot, over the whole page,
  and read every plot as one. A
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) maidr
  did not record, made through
  [`graphics::layout()`](https://rdrr.io/r/graphics/layout.html) or
  before an earlier [`show()`](https://r.maidr.ai/reference/show.md) or
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) on the
  device, keeps the widths and heights R gave its cells too, read from
  where R drew its plots, where every edge of its cells is an edge of
  one and its cells fill the page, where maidr drew its columns all as
  wide, and its rows all as tall, as each other. Its plots are read in
  the grid of those cells too, as a recorded
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s are,
  so a reader moves through other subplots than before: maidr read the
  plots of `graphics::layout(matrix(c(2, 1), 1), widths = c(1, 3))`, or
  of a scatter plot with marginal plots laid out with `widths` and
  `heights`, as one subplot of several layers, and a plot spanning a row
  of cells over rows of other heights as a subplot in the first of them
  only. Each plot is now a subplot of the cell R drew it in, in each
  cell it spans, and a cell no plot was drawn in is an empty subplot.
  Such a layout’s cells keep the share of the page R gave them on the
  device the plots were drawn on, which is their size on a page of any
  size where `widths` and `heights` set it, but not where
  [`lcm()`](https://rdrr.io/r/graphics/layout.html) did, and R does not
  say which. A size no one asked for is enlarged until those shares
  leave every plot room, as for a recorded
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md), and the
  message says it is the shares: an `lcm(4)` column drawn on a 10 x 8 in
  device is then drawn at 9 x 5 in, where R draws it 4 cm wide at 7 x 5
  in. At a size asked for that they leave a plot no room at, the cells
  are drawn the same size, as before, rather than the chart stopping,
  both where R draws the page, as for that `lcm(4)` column at 7 x 5 in,
  and where R stops, as for relative `widths` of 5 : 1 there. The one
  cell of such a layout is read as R reports it, a region of the page as
  `par(fig = )` gives one, so a cell sized with
  [`lcm()`](https://rdrr.io/r/graphics/layout.html) keeps its share of
  the author’s page: drawn smaller than that page, the chart can stop
  where R draws it. A grid set up without maidr after a recorded
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) of its
  shape, as `withr::with_par(list(mfrow = c(1, 2)), ...)` after
  `layout(matrix(1:2, 1), widths = c(1, 3))`, is not given the recorded
  call’s sizes: maidr reads the regions R drew the page’s plots in,
  which are the recorded call’s cells only where R drew them in that
  layout ([\#361](https://github.com/xability/r-maidr/issues/361)).
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) of a
  lattice chart exports that chart even while a Base R call is recorded
  on the current device. The Base R adapter claimed any object once the
  device held a recorded call, so the chart was written out as the
  recorded Base R chart instead. The adapter now leaves a ggplot2 or
  lattice object to that package’s reading, whatever order the plotting
  systems were registered in
  ([\#333](https://github.com/xability/r-maidr/issues/333)).
- [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
  lattice or ggplot2 object is no longer recorded as a Base R chart.
  maidr’s [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  wrapper took the call for one: with no graphics device open it drew
  the chart on the hidden device Base R recording uses, so nothing
  appeared, and a later [`show()`](https://r.maidr.ai/reference/show.md)
  opened an empty scatter plot. The call now passes straight to the
  package’s own
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) method
  ([\#333](https://github.com/xability/r-maidr/issues/333)).
- `layout(1)`, and `par(op)` with the settings `op <- par(mfrow = ...)`
  saved, are read as the resets they are: a chart drawn after one is
  read as a single panel. maidr kept the grid set before the reset, and
  described the chart as one panel of a grid whose other panel was empty
  ([\#352](https://github.com/xability/r-maidr/issues/352)).
- A Base R chart is titled the way R titles it. `hist(mtcars$mpg)`
  writes “mtcars\$mpg" under its x axis and "Histogram of mtcars\$mpg”
  above it, and the chart maidr drew, in
  [`show()`](https://r.maidr.ai/reference/show.md),
  [`save_html()`](https://r.maidr.ai/reference/save_html.md), a knitted
  document and the static image a chart falls back to, wrote the values
  instead, “c(21, 21, 22.8, 21.4, …)” for as long as the data ran: maidr
  draws the chart again from the values it recorded, and R names these
  titles after how an argument was written. The same went for the other
  charts R titles that way, among them `plot(x, y)`,
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
  vector, a time series or a table,
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`persp()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`matplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`sunflowerplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md), and
  for two arguments written alike, as in `plot(rnorm(100), rnorm(100))`.
  The chart is still drawn from the recorded values, so each chart a
  loop draws, or one drawn from
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html), shows the data it
  was drawn with. An argument written longer than R lets a name be
  (10,000 bytes), or written as `..1`, is still titled with its values
  ([\#353](https://github.com/xability/r-maidr/issues/353)).
- The data a screen reader reads names a Base R chart’s axes, and a
  histogram’s title, as the chart draws them. `hist(mtcars$mpg)` was
  read as a histogram over “Bin” with no title, and `plot(x, y)` and
  `qqplot(x, y)` with no axis names at all, because the recorded values
  no longer said how the arguments were written. The call now keeps that
  text, so a histogram is read as “Histogram of mtcars\$mpg" over
  "mtcars\$mpg”, `plot(v)` as “Index” against “v”, and the lines and
  density curves drawn over either chart name the same axes. A title the
  call gives, or blanks with `main = NULL`, still wins
  ([\#353](https://github.com/xability/r-maidr/issues/353)).
- A Base R chart titled with a plotmath call,
  `main = bquote(mu == .(n))` or `xlab = quote(x[i])`, keeps its drawing
  and its data. maidr handed the recorded call on to be evaluated, so
  the chart maidr exported had nothing drawn on it, a box plot or Q-Q
  plot was read with no data, an axis was named “\[” in the data, and
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) stopped
  at the call itself with “object ‘mu’ not found”. The call is now
  recorded as the expression it stands for, which R draws the same
  ([\#353](https://github.com/xability/r-maidr/issues/353)).
- A Base R chart whose title or axis title is not one string is drawn as
  R draws it. `i <- 3; plot(1:5, main = i)` and
  `barplot(c(1, 2, 3), xlab = 2024)` were exported with nothing drawn on
  them, and nothing said so: the drawing maidr makes of a Base R chart
  again stopped on a `main`, `sub`, `xlab` or `ylab` given as a number,
  a logical, several values or a list such as `list("Title", font = 2)`,
  or as plotmath to
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  `ylab = quote(x^2)`, or to a formula
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  `main = expression(alpha)`; on a
  [`title()`](https://r.maidr.ai/reference/base-r-wrappers.md) given
  several `line` or `outer` values, none, or a missing `outer`; on an
  [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) given
  several values of `side`, `tick`, `pos`, `outer`, `font`, `lwd` or
  `lwd.ticks` or a missing `outer`, `lwd` or `lwd.ticks`, on
  `axis(labels = NA)` and `axis(1, at = numeric(0))`; and on an
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) spread
  over several sides, `adj` or `padj` values, such as
  `mtext(c("Left", "Right"), side = c(2, 4))`. It left out values of an
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) whose
  `at` held fewer positions than values, or a missing one, drew a
  missing [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  text or tick label as “NA”, and drew an axis’s ticks in each of
  several `col`, `col.ticks` or `lty` values in turn. Each is now drawn
  as R draws it, several values of `main`, `xlab` or `ylab` a line apart
  and those of `sub` all on its one line, and the title and axis titles
  a screen reader reads are the same text, a line for each value: they
  were the first value alone. The titles of
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md), and of a
  formula plot with a `subset`, written as code, such as `main = grp` in
  a loop, are read the same way, and drawn with the values R drew them
  with: they were announced as the first word of the code, or as no
  title, and drawn by running the code again, so that a title holding
  [`sample()`](https://rdrr.io/r/base/sample.html) or a counter was
  drawn with another value. The y axis of a
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of several
  time series, drawn a panel each, is announced as the first series’
  name, the title R gives its panel; it was the `ylab` R does not draw.
  A chart that still cannot be drawn again, such as one with
  `axis(1, padj = c(0, 1))`, falls back to the static image, with a
  warning that says why, rather than being exported empty; the image’s
  alt text says it could not be made interactive, and names the page it
  shows, the last one R drew: by the chart’s title, or for several
  panels by the title R drew over them or by each panel’s own, its
  plot’s or
  [`title()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s. In a
  knitted document it stays knitr’s figure, and the document’s build
  says why once, as it does for a chart whose build stops
  ([\#358](https://github.com/xability/r-maidr/issues/358)).
- [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
  function, such as `plot(sin, -pi, pi)`, `plot(dnorm, -3, 3)` or
  `plot(function(x) x^2)`, is read as the line
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws for
  it, over the points R drew, wherever the function is written among the
  arguments, as in `plot(main = "Sine", sin, -pi, pi)`.
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) and
  [`show()`](https://r.maidr.ai/reference/show.md) stopped with “object
  of type ‘builtin’ is not subsettable” (or ‘closure’ or ‘special’), a
  knitted chunk showed a picture of it, and `plot(sin)` with no range,
  or with only `from`, `to` or `xlim`, was read as a scatter with no
  points. Its axes are named as R names them, “x” and the first line of
  the function as written, “sin”. Drawn over another chart with
  `add = TRUE`, or as points with `type = "p"`, it is shown as a picture
  of the chart, as
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) is. A
  function of `TRUE` and `FALSE`, such as `plot(function(x) x > 0.5)`,
  is read at the 0 and 1 R draws it at, and so is `curve(x > 0.5)`,
  which was read as a line with no points; one whose values are other
  than numbers, such as dates, is shown as a picture.
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a time
  series of one series, a one-way table or a data frame of two columns
  is announced with the axis titles R draws for it, such as “Time” and
  “AirPassengers” for `plot(AirPassengers)`, where it had none, or had
  them only with another argument written first, as in
  `plot(main = "Nile", Nile)`. So written, a time series is read as the
  line R draws for it and `plot(main = "D", density(x))` as the density
  curve, as they are written first, where each was read as a scatter of
  its points. A title
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) derives
  for an axis, such as “Time”, “v” for `plot(v)`, “mpg” for
  `plot(mpg ~ wt, data = mtcars)` or “Density” for `plot(density(x))`,
  is not announced where R draws none: where the call blanks it, as
  `ylab = ""` does, or gives it as `NULL` to a time series, or turns
  titles off with `ann = FALSE` or `par(ann = FALSE)`.
  `plot(v, ylab = "")` was announced with “v”. A title written on an
  axis after the plot with `title(xlab = )` or `ylab` is announced as R
  draws it there: `plot(x, y, ann = FALSE); title(xlab = "Weight")` was
  announced with “x”. So is one written with
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) centred
  on that side, the string nearest the axis where there are several,
  where maidr announces no title of its own for that axis, as for
  `plot(x, y, ann = FALSE)`. A bar chart, box plot or strip chart keeps
  maidr’s “Category” and “Value”, or a formula’s names, and
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) keep the
  titles they derive, even where R draws none. On a chart of several y
  axes, drawn with `par(new = TRUE)` and `axis(4)`, each series is
  titled by what is written beside its own axis
  ([\#359](https://github.com/xability/r-maidr/issues/359)).
- A Base R chart is the page R’s device shows: the last one. After
  `hist(mtcars$mpg); hist(mtcars$hp)` R shows the second histogram
  alone, on a page of its own, but
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) made one
  chart of every plot drawn on the device: both histograms’ data in one
  subplot, under a drawing of the first, so a reader heard data that was
  not on the chart, and saw a chart R no longer showed. The same
  happened whenever a plot started a new page, as `plot(x)` and then
  `heatmap(m)`, or a fifth plot under `par(mfrow = c(2, 2))` after a
  reset to one panel. maidr now reads the page each call was drawn on
  from R itself, so the chart is the last page, with all the panels of a
  `par(mfrow)`, `par(mfcol)` or
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) grid on
  it, each plot in the panel R drew it in – also when maidr did not
  record the call that set the grid up, made through
  [`graphics::par()`](https://rdrr.io/r/graphics/par.html) or
  [`withr::with_par()`](https://withr.r-lib.org/reference/with_par.html),
  or before an earlier [`show()`](https://r.maidr.ai/reference/show.md)
  or [`save_html()`](https://r.maidr.ai/reference/save_html.md) on the
  device, or when a plot is drawn over the whole page after
  `par(mfrow = c(1, 1), new = TRUE)`, as a legend for all the panels is,
  where maidr read every plot as a layer of one subplot. A plot drawn
  after `par(new = TRUE)` is drawn over the plot before it, in its
  panel, where maidr drew the first alone or gave the second a panel of
  its own; an inset drawn after `par(fig = , new = TRUE)`, or a plot in
  a screen of
  [`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  is drawn in the region of the page R gave it; a plot `par(mfg = )`
  sends to a panel out of turn is in that panel;
  [`plot.new()`](https://rdrr.io/r/graphics/frame.html) and
  [`frame()`](https://rdrr.io/r/graphics/frame.html) take a panel as
  they do in R, where maidr moved the next plot into it; a
  [`legend()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`text()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) drawn on
  such a panel, or on a plot maidr does not record such as
  [`smoothScatter()`](https://rdrr.io/r/graphics/smoothScatter.html), is
  drawn there, where maidr drew it over the plot before and read it as
  part of that plot; one drawn over a plot after `par(new = TRUE)` and
  [`plot.new()`](https://rdrr.io/r/graphics/frame.html), as a second
  series with an axis of its own is, is drawn in the coordinates it was
  drawn in, where maidr drew it in the plot’s, and is read with that
  plot also in an earlier panel or screen `par(mfg = )` or
  [`screen()`](https://rdrr.io/r/graphics/screen.html) sent R back to,
  where maidr read it with the plot drawn last; one drawn after
  `par(mfg = )`, or `screen(n, new = FALSE)` of
  [`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  sends R back to the panel or screen of an earlier plot is drawn on
  that plot and read with it, where maidr read it with the plot drawn
  last, and drew it on that plot or not at all – but not what R clips
  away: after `screen(n, new = FALSE)`, until
  [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`title()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`box()`](https://rdrr.io/r/graphics/box.html) or a change of `xpd`
  works R’s clip out again, R clips what is drawn to the plot in the
  screen before and shows none of it, and maidr neither draws nor reads
  it; and nothing drawn on an earlier page – its data, titles,
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
  [`legend()`](https://r.maidr.ai/reference/base-r-wrappers.md), or a
  size it would need – reaches the chart, even when the plot that
  started the new page was drawn while
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) was in
  effect. A page
  [`replayPlot()`](https://rdrr.io/r/grDevices/recordplot.html) puts
  back on a device that keeps a display list is the chart, with what was
  drawn on it when
  [`recordPlot()`](https://rdrr.io/r/grDevices/recordplot.html) saved
  it, where maidr read the plots and calls drawn since with it.
  [`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md) without
  `add = TRUE` draws a plot of its own, and is the plot of its page,
  shown as a picture since maidr does not read it, where
  [`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md) alone
  gave a chart with nothing on it. A page that holds no plot maidr
  recorded, as after `hist(x); plot.new()`,
  `hist(x); plot.new(); text(0.5, 0.5, "note")` or
  `hist(x); smoothScatter(y)`, or a page
  [`replayPlot()`](https://rdrr.io/r/grDevices/recordplot.html) puts
  back from a plot drawn while
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) was in
  effect, is no longer exported as the histogram before it, or as a
  chart with nothing on it:
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) stop and
  say the page holds no plot maidr recorded. So do they, and say why,
  for a line added to a plot an earlier
  [`show()`](https://r.maidr.ai/reference/show.md) or
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) read, or to
  a page [`replayPlot()`](https://rdrr.io/r/grDevices/recordplot.html)
  puts back from before then: that call let go of what maidr recorded of
  it. A plot drawn over the one before it after a `par(new = TRUE)` made
  through [`graphics::par()`](https://rdrr.io/r/graphics/par.html) or
  [`withr::with_par()`](https://withr.r-lib.org/reference/with_par.html)
  is titled as after one maidr records: on a chart of two y axes, each
  series by what is written beside its own axis, where every title went
  to the second series. A plot in a screen of
  [`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
  drawn with the margins and size of text R drew it with, those
  [`screen()`](https://rdrr.io/r/graphics/screen.html) puts back for
  that screen, and without the outer margins
  [`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  takes away while its screens are in use, where maidr drew it with
  those set last in any screen, under outer margins R had taken away;
  and so is a plot whose margins or size of text a
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) call made
  through [`graphics::par()`](https://rdrr.io/r/graphics/par.html) or
  [`withr::with_par()`](https://withr.r-lib.org/reference/with_par.html)
  set, which maidr drew with R’s own. The picture maidr draws of a page
  it cannot read or draw again has each plot where R drew it too – over
  the plot before it, in its panel of a grid, or in its screen or region
  of the page – also where what put it there was not recorded: a
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) call made
  through [`graphics::par()`](https://rdrr.io/r/graphics/par.html) or
  [`withr::with_par()`](https://withr.r-lib.org/reference/with_par.html),
  [`screen()`](https://rdrr.io/r/graphics/screen.html), or a panel
  [`plot.new()`](https://rdrr.io/r/graphics/frame.html) took; and what
  `par(mfg = )` or `screen(n, new = FALSE)` sent R back to add is drawn
  on the plot R added it to, clipped as R clips it. The picture drew a
  plot after such a `par(new = TRUE)` on a page of its own, which lost
  the plots before it, as on a chart of two y axes whose second axis
  maidr cannot draw again; drew one such a `par(mfg = )` sent out of
  turn, or one after a panel
  [`plot.new()`](https://rdrr.io/r/graphics/frame.html) took, in the
  next panel; drew every plot of a call that draws several, as
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
  fitted model does, on one page, where R shows the last of them; and
  drew a
  [`split.screen()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  page’s last plot alone in the first screen’s place, with R’s warning
  “calling par(new=TRUE) with no plot”
  ([\#360](https://github.com/xability/r-maidr/issues/360)).

### Documentation

- The README gains an “R Markdown and Quarto” section, and it, the
  getting-started vignette,
  [`?maidr_on`](https://r.maidr.ai/reference/maidr_on.md) and the
  examples say that
  [`library(maidr)`](https://github.com/xability/r-maidr) is enough in a
  document; the example articles no longer call
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md)
  ([\#352](https://github.com/xability/r-maidr/issues/352)).
- A new examples article, “lattice Chart Examples”, shows every lattice
  reading on a small chart, each marked **\[experimental\]**, and is
  listed under “Experimental plot families” on the examples hub and in
  the pkgdown Articles menu. The README gains a lattice table under
  “Experimental Plot Types” and says what printing a lattice chart does;
  the getting-started vignette shows lattice use, and it and
  [`?maidr`](https://r.maidr.ai/reference/maidr-package.md) list
  lattice’s readings as experimental. Five lattice example scripts ship
  with the package, listed by
  [`run_example()`](https://r.maidr.ai/reference/run_example.md) and run
  with `run_example("<name>", type = "lattice")`
  ([\#333](https://github.com/xability/r-maidr/issues/333)).

## maidr 0.5.0

CRAN release: 2026-09-29

### New Features

#### plotly, highcharter and echarts4r widgets

- [`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
  makes an interactive chart drawn by plotly
  ([`plot_ly()`](https://rdrr.io/pkg/plotly/man/plot_ly.html),
  [`ggplotly()`](https://rdrr.io/pkg/plotly/man/ggplotly.html)),
  highcharter or echarts4r accessible, by attaching the MAIDR JavaScript
  adapter for the library that draws it
  ([\#332](https://github.com/xability/r-maidr/issues/332)). The chart
  is read in the browser once it has been drawn, so it works wherever
  the widget does: the viewer,
  [`htmlwidgets::saveWidget()`](https://rdrr.io/pkg/htmlwidgets/man/saveWidget.html),
  R Markdown, Quarto and Shiny, where a re-rendered chart is read again.
  It is pipe-friendly (`w |> maidr_htmlwidget()`) and loads the bundled
  scripts unless `use_cdn = TRUE`. An echarts4r chart is switched to
  ECharts’ SVG renderer, which MAIDR needs to highlight the mark being
  read. The Highcharts and ECharts adapters are bundled beside
  `maidr.js`, from the same verified npm release.

#### maidr.js from the CDN

- The CDN paths now load the latest published maidr.js, as the Python
  binding does, rather than the version bundled with the package. That
  is [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) with
  `use_cdn = TRUE`, and the widget, knitr and Shiny paths, which use the
  CDN when they find the machine online. The first CDN document in an R
  session asks jsDelivr’s data API, then the npm registry, which version
  is the latest, within 3 seconds for both (`maidr.cdn_timeout` or
  `MAIDR_CDN_TIMEOUT`, clamped to 0.1 to 30), and every document in the
  session names that exact version, so what a reader loads does not
  shift under jsDelivr’s week-long cache of the `@latest` tag. The
  answer is kept for the session, and so is a failure: offline or
  blocked, the lookup costs no error and is not retried on every render,
  and documents name the bundled version, as py-maidr’s do. An answer
  older than the bundled version is refused the same way.
  `options(maidr.cdn_version = ...)` or `MAIDR_CDN_VERSION` pins it
  instead: a version (`"4.9.0"`, or `"v4.9.0"`), `"bundled"` for the
  bundled version or `"latest"` for the `@latest` tag, the two tags
  without a lookup; the option wins over the variable, and anything else
  warns once and is ignored. `use_cdn = FALSE` still loads the bundled
  copy and makes no version lookup. See
  [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

#### Languages other than English

- A document that loads the bundled maidr.js now reads charts in the
  reader’s language when maidr.js speaks it: Korean, Japanese, Chinese,
  Spanish, German, French, Italian or Hindi, besides English. maidr.js
  (4.8.0 and later) keeps each of those in a locale pack it fetches from
  beside itself, and this package does not bundle the packs (0.8 MB), so
  these documents stayed in English even online. Every `use_cdn = FALSE`
  document, and every one that inlines the bundle, now declares
  `window.maidrLocaleBaseUrl` ahead of maidr.js, pointing it at the
  packs of the bundled version on jsDelivr. English still needs no
  network; another language is fetched when the reader is online and
  stays English when they are not. A CDN document is unchanged: its
  packs are beside the copy it loads.
  `options(maidr.locale_base_url = ...)`, or `MAIDR_LOCALE_BASE_URL`,
  names another place for the packs, and `""` or `FALSE` declares
  nothing. See
  [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

#### DotPad tactile display

- A DotPad tactile display can now be reached from a fully offline
  document without naming a server.
  [`maidr_download_dotpad_sdk()`](https://r.maidr.ai/reference/maidr_download_dotpad_sdk.md)
  fetches the SDK maidr.js is pinned to (about 14 MB, once, into a
  per-user cache, every file verified against its recorded size and
  digest), and from then on
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) copy it
  into `lib/dotpad-sdk-<version>/` beside every `use_cdn = FALSE`
  document and declare the globals with that relative path. The options
  `maidr.dotpad_sdk_url` and `maidr.dotpad_asset_base_url` still name a
  copy served from elsewhere, and win over a downloaded one;
  `maidr.dotpad_sdk_dir` (or `MAIDR_DOTPAD_SDK_DIR`) moves the cache.
  The widget, knitr and Shiny paths keep using the URL options only:
  their charts live in `srcdoc` frames, where a relative path has
  nothing to resolve against.
- The SDK’s braille engine now comes from the vendor’s own repository.
  maidr.js served `liblouis.data` from a fork because the vendor’s copy
  had its line endings rewritten by git, which broke every braille table
  and dropped the text line to grade 1; upstream has fixed that, and the
  next maidr.js release pins the repaired commit.
- The SDK pin now moves with the maidr.js bundle instead of living in R
  code. `inst/dotpad-sdk.json` is the `dist/dotpad-sdk.json` the maidr
  npm package ships as the single source of truth for its own pin, and
  `.github/scripts/fetch-maidr-bundle.sh` copies it in with every bundle
  refresh. The pin is SDK 3.0.3, served from
  `xability/dotpad-sdk-guide`: the vendor publishes 3.0.3 only as a zip
  archive, so that mirror carries the extracted files, byte-verified
  against the archive. The download cache moves to `dotpad-sdk/3.0.3`
  and documents carry `lib/dotpad-sdk-3.0.3/`.

#### ggplot2

- Added ROC curve support: a receiver operating characteristic curve is
  emitted as a `roc` layer, one curve per classifier, so a reader hears
  the true positive rate on the unit interval, each point’s threshold
  and height above the chance diagonal, and the area under each curve
  and the best operating point in the description.
  [`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) declares
  one – it is
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  with a `threshold` aesthetic and an `auc` argument – and
  [`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html) and
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  of a
  [`yardstick::roc_curve()`](https://yardstick.tidymodels.org/reference/roc_curve.html)
  are read as they stand, by the `sensitivity` and `specificity` they
  map. The trace needs maidr.js 4.9.0 or later (this release bundles
  4.11.0); an older bundle keeps the line reading these charts had.
- Added pie chart support: a
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  layer under `coord_polar("y")` or `coord_radial(theta = "y")` is
  emitted as a `pie` layer, one navigable slice per wedge.
  `coord_polar("x")` and multi-ring charts keep their bar reading.
- A pie layer now says where its ring begins and which way its wedges
  run (`startAngle`, degrees clockwise from 12 o’clock, and
  `direction`), read off
  [`coord_polar()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)’s
  `start` and `direction`, or
  [`coord_radial()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)’s
  `arc` and `reverse`, and off the way the stack was built. maidr.js
  walks every pie clockwise from that start, pans each slice to where it
  sits and names its clock position on `p`; a default ggplot2 pie, whose
  wedges are built from the top of the stack down, is declared
  counterclockwise so the walk is turned round to match the drawing. A
  bundle older than the one that reads the keys ignores them.
- Added step plot support:
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  is emitted as a `step` layer, one point per sample, with
  `stepDirection` (`"hv"`, `"vh"`, `"mid"`). An ordinal factor y carries
  its level name as `label`.
  [`stat_ecdf()`](https://ggplot2.tidyverse.org/reference/stat_ecdf.html)
  is read as one staircase per group;
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  on other computed stats is not read.
- Added 100% stacked bar support: `geom_bar(position = "fill")` is
  emitted as `stacked_normalized_bar`, announcing each segment’s share
  rather than its count.
- Added area chart support:
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  is emitted as `area`, `stacked_area` or (`position = "fill"`)
  `stacked_normalized_area`, one point per input row and one highlight
  per series. In stacked layers `y` is the series’ own value.
  `geom_area(stat = "density")` remains a smooth.
- Added error bar support:
  [`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
  [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
  [`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
  [`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  and
  [`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  are emitted as `error_bar` layers in either orientation, each interval
  highlighted. A layer with no estimate aesthetic reports the centre of
  its span; a dodged layer emits one series per group.
- [`geom_ribbon()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  is read: from a zero baseline as an `area`, otherwise as an
  `error_bar` band (no highlight). `geom_smooth(se = TRUE)` carries its
  confidence band as `yMin`/`yMax` on each fitted point, in faceted
  plots too;
  [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
  is not given a band.
- [`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html),
  [`stat_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  and
  [`geom_quantile()`](https://ggplot2.tidyverse.org/reference/geom_quantile.html)
  are read as smooth curves.
  [`stat_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  with a geom the smooth reader cannot draw no longer stops
  [`save_html()`](https://r.maidr.ai/reference/save_html.md):
  `geom = "point"` reads as a scatter and `geom = "step"` falls back to
  a static image.
- Added contour support:
  [`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html)
  and
  [`geom_density_2d()`](https://ggplot2.tidyverse.org/reference/geom_density_2d.html)
  are emitted as `contour` layers, one navigable curve per piece with
  its `level`. The filled variants fall back to a static image.
- Added gantt chart support:
  [`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html),
  [`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
  and a flat
  [`geom_spoke()`](https://ggplot2.tidyverse.org/reference/geom_spoke.html)
  (`angle = 0`) are emitted as `gantt` layers when every segment spans
  one axis at a fixed position on the other. Both orientations work, a
  lane with several spans keeps them all, and unused levels survive
  `drop = FALSE`. Segments that share no coordinate, and angled spokes,
  keep the static-image fallback.
- New [`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md): a
  [`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  layer whose author declares it a schedule is emitted as a `gantt`,
  lanes named, each bar highlightable. Nothing else about the chart
  changes – the built data and both panel ranges are identical to the
  bare
  [`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  layer’s – and an undeclared rectangle layer keeps exactly the reading
  it has today. A lane is named by the single explicit tick drawn inside
  it and by its position otherwise; `lane_axis = "x"` reads the mirror
  image. Five structural rules for telling a rect-drawn gantt from a
  heatmap, a waterfall or a highlight were measured against eight charts
  and every one of them claimed a chart the issue forbids, which is why
  the author is asked instead.
- Added
  [`geom_hex()`](https://ggplot2.tidyverse.org/reference/geom_hex.html)
  support: each hexagon is a navigable bin announcing its centre and
  count. ‘hexbin’ is now in Suggests.
- [`geom_raster()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  is read as the same `heat` layer as
  [`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html);
  a raster is a single grob, so its cells are announced but not
  highlighted.
- [`geom_dotplot()`](https://ggplot2.tidyverse.org/reference/geom_dotplot.html)
  is read as a histogram, one bin per stack, in both `binaxis`
  orientations.
- [`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
  is read as one closed `line` series per group (and per `subgroup`).
- [`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html)
  is read as one `point` layer per marked side, each tick highlightable,
  with the axis bounds braille grid mode needs.
- A point on a discrete axis carries its category name
  (`xLabel`/`yLabel`) beside its numeric position, in faceted, dodged
  and jittered plots too.

#### Base R

- [`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)
  candlestick charts keep their volume panel. The panel
  [`addVo()`](https://rdrr.io/pkg/quantmod/man/addVo.html) draws –
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s
  default whenever the data has a Volume column – is read as a second,
  bar layer beside the candles, one bar per period, each highlighted as
  it is read. These charts fell back to a static image before. Another
  indicator ([`addSMA()`](https://rdrr.io/pkg/quantmod/man/addMA.html),
  [`addMACD()`](https://rdrr.io/pkg/quantmod/man/addMACD.html), …) still
  falls back, with the advisory, which now names
  [`addVo()`](https://rdrr.io/pkg/quantmod/man/addVo.html) as the one
  that is read. The volume bars are clipped to their panel, as R draws
  them, rather than running on into the date labels.
- Added Base R
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  one navigable slice per wedge. Text grobs with an `NA` justification
  are repaired so
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) exports
  through gridSVG.
- A [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) layer now
  says where its ring begins and which way it runs: `init.angle` is
  converted from degrees counterclockwise from 3 o’clock to the
  `startAngle` maidr.js reads (degrees clockwise from 12), and
  `clockwise = FALSE`, the default, is declared as
  `direction = "counterclockwise"` so the walk, the audio pan and the
  `p` clock position follow the wedges as drawn rather than the other
  way round.
- Added Base R step plot support:
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
  `type = "s"` or `"S"` are emitted as `step` layers with
  `stepDirection` `"hv"` / `"vh"`.
- Added Base R 100% stacked bar support: a stacked
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) whose
  every column sums to 1 (`barplot(prop.table(m, 2))`) is emitted as
  `stacked_normalized_bar`. Columns summing to 100 and single-row
  matrices stay `stacked_bar`.
- Added Base R violin plot support:
  [`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html)
  is emitted as the `violin_box` + `violin_kde` pair
  [`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)
  produces, replaying
  [`sm::sm.density()`](https://rdrr.io/pkg/sm/man/sm.density.html) with
  the caller’s `h` and `range`; each section highlights its own grob. A
  category with no spread is omitted. The formula interface
  `vioplot(y ~ g)` is not read and falls back to a static image.
- Added Base R
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as `contour` layers from
  [`grDevices::contourLines()`](https://rdrr.io/r/grDevices/contourLines.html)
  at each function’s own default `nlevels`. gridGraphics cannot emulate
  inline level labels, and a filled field exports no per-curve element,
  so
  [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  is announced and navigated but not highlighted.
- [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) is read
  as an interactive line, including when called inside a function that
  binds the expression’s variables. Draw types other than a polyline and
  `curve(add = TRUE)` keep the static fallback.
- `plot(type = "h")` and `lines(type = "h")` are emitted as a `lollipop`
  layer.
- [`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
  one value per category is read as a horizontal `dot` layer; the
  grouped/matrix form still falls back.
- Added Base R
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as a `mosaic` layer: each cell carries its conditional
  proportion, its column’s share of the whole, its count and its fill
  level, with the second dimension named on `z`. Both
  `mosaicplot(table)` and `mosaicplot(~ a + b, data = )` are read; a
  table of three or more dimensions, or a formula call with `subset`,
  falls back to a static image.
- Added Base R
  [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as a `mosaic` layer like
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md). The
  drawn table is recovered by replaying the call off-screen, so a
  numeric `x` announces the interval bins the chart labels; every cell,
  including an empty one, is highlightable.
- Added Base R
  [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  read as a `stacked_normalized_area` layer. Bands come from
  `cdplot(plot = FALSE)`, trimmed to the drawn x range and listed bottom
  to top; a formula call’s `subset` is honoured.
- Added Base R
  [`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support: a Cohen-Friendly association plot is read as a `heat` layer
  of one Pearson residual per cell, with axes named from
  [`dimnames()`](https://rdrr.io/r/base/dimnames.html) and `z` labelled
  “Pearson residual”. Tile widths are not announced.
- Added Base R
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, conditional on the caller’s own `std`: under
  `std = "ind.max"` or `"all.max"` the four quadrants are the four
  counts – measured, `radius^2 * max(count)` recovers each cell exactly
  – so a 2x2 table is read as a `heat` grid of one count per cell, one
  selector per quadrant, with the levels and axis names taken from the
  labels
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  itself draws (including its `Row`/`Col` and `A`/`B` defaults). Partial
  spellings such as `std = "ind"` are read. Under the default
  `std = "margins"` the four radii carry one number, the odds ratio, so
  that call still falls back to a static image and now says why; a 2x2xk
  array falls back too. The confidence arcs are not announced.
- Added Base R
  [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as one `point` layer per group with the group name
  carried as the point label; `group.names`, `at`, `vertical = TRUE` and
  `method = "jitter"` are honoured.
- Added Base R
  [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) support.
  The quantile pairs come from `plot.it = FALSE`, so `datax = TRUE` and
  [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s
  default title and axis labels are read as drawn;
  [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) is read
  as a `line` layer from its own `probs`, `qtype` and `distribution`.
  `qqplot(conf.level = )` still falls back to a static image.
- Added Base R
  [`bxp()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  read as the same `box` layer as
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) from
  the summaries in `z`. `xlab`/`ylab` are used; otherwise the generic
  axis names apply.
- Added Base R
  [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  read as a scatterplot matrix: one `point` cell per off-diagonal panel.
- Added Base R
  [`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  read as a `lollipop` layer of one spike per lag, with the value axis
  named ACF / Partial ACF / CCF.
- Added Base R
  [`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as a multi-series `line` chart of the cell means, one
  series per trace level.
- Added Base R
  [`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as one `line` series per cycle position (named by
  `month.abb` for a monthly series). The `base` reference segments are
  not announced.
- Added Base R
  [`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as a grid of `point` cells, one per series and lag.
- Added Base R
  [`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  read as a `radar` layer: one series per row and one spoke per column,
  announcing the caller’s values rather than the scaled radii. No
  highlight yet.
- Added Base R
  [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  support, read as one `line` cell per term on the last page drawn;
  factor terms are declined.
- Added Base R
  [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) support:
  a `line` over the spectral density and a `step` over the cumulative
  periodogram. The confidence and KS reference marks are not announced.
- Added Base R
  [`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  read as two `point` cells, scores and loadings, each on its own axes.
- Added Base R word cloud support:
  `wordcloud::wordcloud(words = , freq = )` is read as a `word_cloud`
  layer of terms and their counts, honouring `min.freq` and `max.words`.
  Attach ‘wordcloud’ before ‘maidr’ or call
  [`maidr::wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  with `words` and `freq` named or positional. No highlight.

### Bug Fixes

#### Rendering and integration

- A chart rendered with `use_cdn = FALSE`, or offline, works again when
  R runs under a C locale (a container, a CI runner, many servers). The
  chart’s frame carries maidr.js inline in its `srcdoc` attribute, and
  the bundle’s non-ASCII characters travelled as raw bytes, which
  knitr’s output and an htmlwidget’s JSON rewrote under a C locale as
  `<e2><80><a6>`; the script no longer parsed, and the chart was a plain
  picture. Every non-ASCII character in the frame’s document is now a
  numeric character reference (`&#x2026;`), which the browser decodes,
  so what goes into the page is ASCII whatever the locale.

- A self-contained R Markdown or Quarto document
  (`self_contained: true`, R Markdown’s default, or
  `embed-resources: true`) rendered online now works offline. Each
  chart’s frame loaded maidr.js from the CDN through a `<script src>`
  inside its `srcdoc` attribute, where pandoc’s resource embedding
  cannot see it, so the document still needed the network and offline
  its charts were plain pictures. The knitted document now carries one
  copy of the bundle, embedded or in its `_files` folder like any other
  dependency, in a script no browser runs; a chart whose CDN load fails
  reads that copy from the page instead. The CDN is still tried first.

- The widget (`show(..., as_widget = TRUE)`, and
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) in
  Shiny) does the same. Its chart frame now falls back to a copy of the
  bundle on the widget’s page, so a self-contained document holding
  widgets works offline too, and so does a Shiny app whose readers
  cannot reach the CDN. The page already carried that copy, as a script
  it ran for nothing: each chart runs in its own frame, where the page’s
  copy could not reach it. It is now an inert script, shared with the
  knitted charts’ copy, and only a widget whose frame loads from the CDN
  adds it: a widget drawn with `use_cdn = FALSE`, or offline, carries
  the bundle in its frame and puts no copy on the page, where every
  widget used to add 1.7 MB it never read. The widget no longer has an
  `htmlwidgets` yaml, so the bundle refresh rewrites `MAIDR_VERSION`
  alone.

- Bar, histogram, scatter, dodged, stacked and normalized bar, pie, dot
  and lollipop layers highlight again with the bundled maidr.js 4.x, on
  ggplot2 and Base R alike. Every processor built `selectors` with
  [`list()`](https://rdrr.io/r/base/list.html), so a single CSS selector
  reached the payload as a one-element JSON array; maidr.js 3.x read
  that as the string it held, and 4.0 changed the contract so an array
  names one selector per data point (or a per-series grid), resolved one
  element for seven bars, and dropped the layer’s highlight while
  navigation and speech kept working. The payload now carries a plain
  string for every layer type whose frontend model reads one selector
  for all of its marks, joined with `", "` when a processor names
  several containers, and a bar layer in a panel that holds a second bar
  layer now addresses its own rects rather than both layers’.

- Dodged, stacked and normalized bars, ggplot2 and Base R, highlight the
  bar being announced. maidr.js 4.0 also stopped inferring that a
  layer’s rects are drawn category by category: a layer that does not
  say `domMapping.order = "column"` is paired with its rects series by
  series, so once the highlight came back it landed on the wrong bar –
  “a, 10, u” announced while the 55 bar was outlined. Every segmented
  layer now declares the order it is drawn in. A headless-browser smoke
  test in CI presses the arrow keys on each of these charts and fails
  when nothing changes colour or when the outlined bars do not rank the
  way the announced values do, which is the check the 4.0.0 bundle
  refresh did not have
  ([\#316](https://github.com/xability/r-maidr/issues/316)).

- Every layer type was then driven through the bundled maidr.js in
  headless Chromium, and the charts that still drew no highlight, or
  drew it on the wrong mark, are fixed for the same reason: the shape
  the frontend reads changed with 4.0 and the emitters had not followed
  ([\#316](https://github.com/xability/r-maidr/issues/316)).

  - A ggplot2 gantt
    ([`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
    schedules,
    [`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md))
    threw inside the frontend and took the whole figure with it – no
    announcement at all. The frontend reads `data.points` and
    `data.lanes`; the layer emitted the lanes as `data` and the names
    beside it. Base R
    [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md),
    [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
    [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
    threw the same way: their `data` was a flat list of points where the
    line model reads one series per array.
  - Base R
    [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md),
    [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
    [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) also
    addressed the `<g>` holding their curve rather than the polyline, so
    no marker could be placed;
    [`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
    addressed a container id without the `.1` gridSVG appends; a
    [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
    listed its tiles in drawing order in a flat list that
    `querySelectorAll()` resolved in document order, so every tile after
    the first was outlined for another cell; a
    [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
    with an empty cell declined to address any tile at all. Each now
    emits the per-cell grid the segmented and heat models read, `null`
    where nothing was drawn, and
    [`geom_bin_2d()`](https://ggplot2.tidyverse.org/reference/geom_bin_2d.html)
    does the same for its empty bins.
  - A dodged or stacked bar inside a patchwork composition was drawn
    from its rows as given, while every other path reorders them first,
    so its declared drawing order matched the drawing only by luck. A
    pie inside a composition had no selectors at all:
    [`coord_polar()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)
    fixes the aspect ratio, and patchwork then places the leaf under a
    name the panel walk dropped. A bar layer in a composition, whose
    panel carries no placeholder before its layers, could not find its
    own slot.
  - [`geom_rug()`](https://ggplot2.tidyverse.org/reference/geom_rug.html)
    is emitted as the frontend’s own `rug` trace (with the axis it marks
    as `orientation`), which pairs each tick with its own element and
    announces the observation; read as points, a `<line>` tick could
    never be outlined.

- An offline document (`use_cdn = FALSE`) can reach a DotPad tactile
  display without the network. maidr.js does not bundle the DotPad SDK
  and imports it from jsDelivr the first time a DotPad connects; the new
  options `maidr.dotpad_sdk_url` and `maidr.dotpad_asset_base_url` (or
  the environment variables `MAIDR_DOTPAD_SDK_URL` and
  `MAIDR_DOTPAD_ASSET_BASE_URL`) point it at a copy you serve instead.
  They are written ahead of `maidr.js` on every path that loads it:
  [`show()`](https://r.maidr.ai/reference/show.md),
  [`save_html()`](https://r.maidr.ai/reference/save_html.md), the
  widget, knitr and Shiny. Without them a DotPad needs network access on
  first connect, which the offline documentation now says
  ([\#304](https://github.com/xability/r-maidr/issues/304)).

- A ggplot2 chart that maidr can read but cannot export gets its static
  picture. The fallback printed the chart through maidr’s own print
  method, which rebuilt it, failed again and opened a fresh
  [`png()`](https://rdrr.io/r/grDevices/png.html) device on every round
  until R ran out of them.

- The Base R fallback picture no longer records its own replay, which
  left phantom layers on the next device R opened. A Base R chart that
  gridSVG cannot export (`matplot(matrix(1:12, 4))`,
  [`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md)) falls
  back to the static picture with a warning instead of stopping
  [`save_html()`](https://r.maidr.ai/reference/save_html.md);
  `maidr_set_fallback(enabled = FALSE)` re-raises the error.

- `maidr_set_fallback(format = "svg")` is honoured, and
  [`maidr_set_fallback()`](https://r.maidr.ai/reference/maidr_set_fallback.md)
  keeps the settings it is not given.

- `show(as_widget = TRUE)` and
  [`maidr_widget()`](https://r.maidr.ai/reference/maidr_widget.md)
  accept Base R plots. Shiny’s
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md)
  renders Base R plots
  ([`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)) and
  renders nothing for a reactive that draws nothing. Recorded calls are
  cleared on the widget and Shiny paths.

- knitr: [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md)
  disables RMarkdown interception and clears the recorded Base R calls,
  so a later [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) no
  longer replays them as phantom layers; PDF and LaTeX output use
  ggplot2’s own print method and knitr’s original plot hook; a second
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) cannot
  capture maidr’s hook as the original.

- Tabbing out of a chart hands focus back to the page. The page checks
  that an element actually took focus (Shiny’s `display: contents`
  wrappers refuse silently) and walks up to one that does, and in a
  Quarto `revealjs` deck focus returns to the slide so the deck’s own
  keys work. Applies to the knitr,
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) and
  [`maidr_widget()`](https://r.maidr.ai/reference/maidr_widget.md)
  paths.

- LaTeX in MAIDR’s AI chat responses is styled again: the bundle ships
  `maidr-math.css` beside `maidr.js`, with the embedded KaTeX fonts
  stripped to stay under CRAN’s size limit. `inst/COPYRIGHTS` lists the
  components that bundle embeds (D3 and Tone.js were listed and are not
  in it).

- CDN-versus-bundled auto-detection re-probes internet access every five
  minutes instead of once per session.

- maidr-data JSON keeps full numeric precision (values were rounded to
  four decimals), iframe content is UTF-8 encoded on every locale, and
  plot ids no longer advance the RNG, so
  [`set.seed()`](https://rdrr.io/r/base/Random.html) scripts stay
  reproducible.

- A non-ASCII label – a Korean or accented title, axis label or category
  name – reached the reader as `<ed><95><9c>` under a C locale (a
  container, a CI runner, many servers): the chart’s document was passed
  through [`enc2utf8()`](https://rdrr.io/r/base/Encoding.html) while
  carrying no encoding mark. It is now converted only when it says what
  it is, and escaped byte-wise.

- Charts are embedded with `srcdoc` rather than a `data:` URL, whose
  opaque origin has neither Web Bluetooth nor Web Serial whatever the
  `allow` attribute says, so a tactile display such as a Dot Pad can be
  reached from an R chart; the frame carries `allow="bluetooth; serial"`
  for a chart inside a cross-origin frame. Reading by touch also needs a
  maidr build that supports the display; the bundled 4.11.0 does.

- [`save_html()`](https://r.maidr.ai/reference/save_html.md) and
  [`show()`](https://r.maidr.ai/reference/show.md) no longer warn
  “number of items to replace is not a multiple of replacement length”
  on a chart with a rect of negative height or width, such as
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) with a
  bar below the baseline.

- A currency prefix other than `$` resolves in every locale;
  `label_dollar(prefix = "€")` was announced as USD outside a UTF-8
  session.

- The startup message says that ggplot2 plots open in the viewer
  automatically while Base R plots are recorded until
  [`show()`](https://r.maidr.ai/reference/show.md) is called, and names
  the masking when ‘quantmod’ is attached after ‘maidr’.

- [`cancel_auto_show()`](https://r.maidr.ai/reference/cancel_auto_show.md)
  removes its task callback by name, so it can no longer remove another
  package’s callback.

- [`show()`](https://r.maidr.ai/reference/show.md) hands an object that
  is not a plot – an S4 object, a vector – to
  [`methods::show()`](https://rdrr.io/r/methods/show.html), which
  attaching maidr masks, so it prints as it did before. It failed with
  “argument is of length zero”
  ([\#320](https://github.com/xability/r-maidr/issues/320)).

#### ggplot2

- A
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  or
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  over a numeric x now emits x as a number (`"x": 0`) rather than a
  string (`"x": "0"`), matching the
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  beside it, so `geom_point() + geom_line(aes(y = trend))` carries the
  same x in both layers and the line’s x takes the axis format. A
  discrete x is still its category label and a `Date` or `POSIXct` x
  still an ISO string.
- A
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  or
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  with a missing y inside the series now announces that position as
  missing (`y: null`), where it dropped it, so
  `x = 0:3, y = c(1, NA, 4, 5)` reads four positions rather than three
  and the gap is heard. The Python binding and the base R line path
  already emit the null. Leading and trailing missing values, which
  ggplot2 does not draw (a moving average’s warm-up), are still left
  out.
- Horizontal bar charts are read correctly:
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  with `aes(y = category, x = value)`, alone or with
  `position = "dodge"`, `"stack"` or `"fill"`, and
  `geom_histogram(aes(y = ))` emit `orientation = "horz"` with values,
  labels and order matching the drawn bars; they came out empty,
  mislabelled or unannounced. Reading such a chart no longer swaps the
  caller’s own layer mapping in place.
  [`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
  is still reported `"vert"`, which reads correctly.
- Faceted plots keep the axis labels ggplot2 derives while building
  (such as “count”) and the legend title, and each panel keeps its
  layers’ `orientation` and `domMapping` hints instead of falling back
  to defaults.
- Faceted plots: a `position = "fill"` bar announces proportions; a
  panel whose facet value is `NA` announces its own rows (dodged bars,
  heat maps and stacked bars, which used to abort the export); an empty
  panel (`drop = FALSE`) carries no layers and no fabricated selector,
  for a smooth or a line as for the other geoms; a bar on a continuous,
  `Date` or `POSIXct` axis announces its own x; a line on a transformed
  x scale announces data values; box plot panels carry their own
  category names; heat map panels report their own cells; box plots,
  histograms, smooths, heat maps and stacked/dodged bars no longer fail
  with “unused arguments”. Faceted violins render but are not
  interactive.
- ‘patchwork’: layer ids are unique across a composition; each leaf’s
  axis number formats and ggplot2-computed axis labels are kept; nested
  layouts (`(p1 | p2) / p3`) emit working selectors for every layer
  type; a violin leaf emits its layers; a faceted leaf no longer
  displaces the plots after it; plots after
  [`inset_element()`](https://patchwork.data-imaginist.com/reference/inset_element.html),
  [`free()`](https://patchwork.data-imaginist.com/reference/free.html)
  or
  [`wrap_elements()`](https://patchwork.data-imaginist.com/reference/wrap_elements.html)
  are described; a leaf whose processor errors is left silent instead of
  failing the composition; a horizontal bar leaf keeps its `orientation`
  and a dodged count leaf its `domMapping`.
- Transformed scales
  ([`scale_x_log10()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html),
  [`scale_x_sqrt()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html),
  [`scale_x_reverse()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)):
  point, line and smooth layers announce the values the axis shows. A
  transformed axis emits its label but no navigation grid.
  [`coord_trans()`](https://ggplot2.tidyverse.org/reference/coord_transform.html)
  is unchanged.
- Curve layers highlight their own polyline: a
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  or
  [`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  beside a later
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html),
  a chart mixing
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  and
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html),
  a grouped `geom_line(aes(colour = g))` beside a
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html),
  and a grouped
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  or
  [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
  (now one series per group, named after it) each get one selector per
  series. When curves cannot be matched to series, no selector is
  emitted.
- Dodged bars: `geom_bar(position = "dodge")` with empty (x, fill)
  combinations emits a full grid (an absent count is `0`) so highlights
  land on the right bar;
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  cells the caller never supplied are `NA`; categories follow the
  plotted order rather than text order; expression aesthetics such as
  `aes(fill = factor(cyl))` work; a missing `x` or `fill` value keeps
  the column ggplot2 draws for it.
- [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  on unsorted data announces each point’s own x; a factor y on
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)/[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  carries its level name as `label`; a multi-series line announces its
  legend title instead of “Group”.
- [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  emits only the rows ggplot2 drew (a missing `x` or `y` shifted every
  later highlight);
  [`geom_jitter()`](https://ggplot2.tidyverse.org/reference/geom_jitter.html),
  [`position_jitter()`](https://ggplot2.tidyverse.org/reference/position_jitter.html)
  and
  [`position_jitterdodge()`](https://ggplot2.tidyverse.org/reference/position_jitterdodge.html)
  announce the observation rather than the displaced position;
  colour/group categories are announced again in faceted scatters, for a
  data column and for an expression such as `colour = factor(cyl)`
  alike.
- Histogram and smooth layers read their own layer’s built data in
  multi-layer plots; heat map axes follow factor level order and are
  named after the mapped columns or
  [`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) rather
  than “x” and “y”;
  [`geom_bin_2d()`](https://ggplot2.tidyverse.org/reference/geom_bin_2d.html)
  is read as the grid ggplot2 computed, each bin named by its range.
- Violin plots: box statistics are read per group from `stat_boxplot`,
  so dodged,
  [`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
  and continuous-x violins announce their own quartiles;
  `geom_violin(width = 0)` no longer errors; a horizontal
  [`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)
  or
  [`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)
  is navigated bottom-up.
- [`geom_hline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html),
  [`geom_vline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html),
  [`geom_abline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html),
  [`geom_label()`](https://ggplot2.tidyverse.org/reference/geom_text.html),
  [`geom_blank()`](https://ggplot2.tidyverse.org/reference/geom_blank.html)
  and
  [`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
  layers are skipped like
  [`geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html),
  so none of them drops the chart to a static image. A layer that drew
  nothing – a recognised geom given zero rows, or an unrecognised one
  whose stat computed no rows because a Suggests package such as
  ‘quantreg’ is missing – no longer reaches the schema or costs the
  chart its interactivity; a plot made only of empty layers still falls
  back.
- A pie layer highlights its wedges on ggplot2 3.4.x too, two polar
  layers on one panel each get their own wedges, and a negative slice
  keeps its sign.
- A box plot is named by the label `scale_x_discrete(labels = )` writes
  on the axis rather than by the raw level.
- Histogram, stacked bar, dodged bar and smooth layers emit no selector
  when the grob lookup finds nothing, instead of guessing an element id.

#### Base R

- A line or step layer (`plot(type = "l")`,
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`matplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  `plot(type = "s")`) over a numeric x now emits x as a number rather
  than a string, as the point layer beside it does.
  [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) labels and
  a `Date` x are still emitted as strings.
- A positional argument reaches the description under the name R matched
  it to (`hist(x, 20)`, `plot(x, y, "l")`), a recorded flag is read as
  the drawing function reads it (`barplot(horiz = 1)`,
  `hist(freq = 0)`), and a recorded argument is looked up by its exact
  name, so `dotchart(v, xlab = )`, `monthplot(x, xlab = )` and
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md) no
  longer read the label as the data
  ([\#292](https://github.com/xability/r-maidr/issues/292)).
- `plot(y ~ x, data = d)` is read as the scatter it draws, from the
  model frame the recording keeps, with the axes named after the two
  variables; [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  and [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  formula calls with `subset =` no longer fail with “object not found”
  or “..3 used in an incorrect context”; a formula recorded with a
  vector `subset` reads only the rows drawn; and a formula is
  snapshotted at record time, so rebinding its variables before
  [`show()`](https://r.maidr.ai/reference/show.md) does not change what
  is announced. A `subset` written as an expression
  (`subset = dose == 0.5`) is evaluated through the snapshot the
  recording keeps, so
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md) formula
  calls read the rows drawn; a formula call whose frame cannot be built,
  and `plot(y ~ f)` on a factor, fall back to a static image rather than
  exporting a chart with no layers.
- A deferred plot call inside a loop
  (`plot(y ~ x, data = d, subset = grp == g)`, `curve(f(x, k))`)
  captures the values its expressions reference at call time, so each
  panel replays its own iteration.
- [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a
  matrix, data frame or list announces the axis grid it draws,
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a time
  series is read as a line over its own time index, `matplot(m)` emits
  one series per column, single-vector `plot(v)` and `lines(v)` calls no
  longer error, `lines(numeric(0))` no longer aborts the render,
  `plot(type = "n")` is declined rather than announced, and multi-series
  selectors sort numerically.
- [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md): a
  matrix without `beside` is read as stacked; `horiz = TRUE` emits
  `orientation = "horz"` for plain, stacked and dodged bars;
  `legend.text` no longer adds legend swatches to the selectors; bar
  data is emitted in drawn order; `height` is read from its own slot, so
  `barplot(beside = TRUE, height = m)` is a dodged bar chart. A named
  vector is still sorted alphabetically before drawing, and the sorted
  arguments are what is recorded.
- [`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md) spans
  the axis [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  set up – the data extended 4% each way, or an explicit `xlim`/`ylim` –
  rather than 5% beyond the data; `spineplot(x, y)` on bare vectors
  names its axes after the variables rather than their written-out
  values;
  [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md) in a
  later `par(mfrow)` panel highlight their own panel’s curve.
- [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) honours
  `right`, `include.lowest` and `nclass`, and density histograms
  announce densities;
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
  `plot = FALSE` and `qqnorm(plot.it = FALSE)` are not recorded.
- [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) follows
  the dendrogram order it draws, labels unnamed axes with the original
  indices it prints, honours `labRow`/`labCol`, and is no longer
  described upside down under `revC = TRUE`;
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md) no longer
  transposes rows and columns; both accept a positional matrix, and cell
  highlights are no longer mirrored.
- Box plots: outlier highlights follow the drawn order, and a box after
  an outlier-free box highlights its own outliers.
- Multi-panel figures:
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) grids
  are multi-panel, a panel spanning several cells carries the panel in
  each, a trailing `par(mfrow = c(1, 1))` no longer collapses the grid,
  plots beyond the grid follow R’s new-page behaviour, plots drawn
  before the layout call are excluded, highlights follow the panel
  actually drawn, per-panel
  [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md) formats
  stay per panel, and an unsupported overlay
  ([`segments()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`arrows()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`rect()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`polygon()`](https://r.maidr.ai/reference/base-r-wrappers.md))
  silences only its own panel, with a warning naming it. Single-panel
  figures still fall back whole, and the static image of a multi-panel
  figure keeps its grid.
- [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) drawn
  without `xlab`/`ylab` announce default axis titles; `main`/`sub` are
  matched exactly (`subset` was read as a subtitle) and tolerate
  non-character values; `main = expression()` no longer fails the save.
- [`stem()`](https://r.maidr.ai/reference/base-r-wrappers.md) is no
  longer recorded as a chart.
  [`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`bxp()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  are recorded and exported, so a bare call is read rather than
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) reporting
  “No Base R plots detected”;
  [`persp()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`sunflowerplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  and
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  are recorded and fall back to a static image instead.
- [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  charts are titled as R titles them. A chart given no `name` was titled
  with its series’ prices printed end to end, because the replay passed
  the recorded data where quantmod reads the expression it was written
  as; the date-range header was placed off the right of the page; and
  the right axis’s line and ticks were drawn through the middle of the
  plot. The title is recorded from the call, the header is placed inside
  the page, and the misplaced axis ticks are dropped with the line,
  keeping the price labels.
- [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md):
  attaching ‘quantmod’ after ‘maidr’ masks maidr’s wrapper, which is now
  reported at attach time and in the “No Base R plots detected” error,
  with
  [`maidr::chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  as the explicit alternative; `maidr::chartSeries(x, TA = NULL)` no
  longer fails when ‘quantmod’ is loaded but not attached; the replay
  always uses the owning namespace’s function rather than maidr’s
  wrapper.
- A wrapped Base R call returns with the visibility of the original, so
  `par("mar")` and `hist(x, plot = FALSE)` print their value again.
- The native-device fallback replays
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls in
  their original order and strips maidr’s internal arguments.
- [`library(vioplot)`](https://github.com/TomKellyGenetics/vioplot) or
  [`library(wordcloud)`](http://blog.fellstat.com/?cat=11) after
  [`library(maidr)`](https://github.com/xability/r-maidr) says, as
  quantmod already did, that the package now masks maidr’s wrapper on
  the search path and that a bare
  [`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
  [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
  goes unrecorded; the “No Base R plots detected” error names it too,
  and the advice is to attach the package first or call
  [`maidr::vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  explicitly ([\#320](https://github.com/xability/r-maidr/issues/320)).

### Enhancements

- Bundled MAIDR.js updated from 3.72.1 to 4.11.0. CDN documents name the
  version resolved once per session rather than `@latest` (see “maidr.js
  from the CDN” above).
- maidr now requires R \>= 4.0.0.
- Iframe height auto-resize works in RMarkdown documents, not only in
  the htmlwidgets binding.

### Documentation

- Help pages render the roxygen markdown they were written in, the
  internal R6 reference pages no longer carry stray keyword entries, and
  `R CMD check` no longer NOTEs “Lost braces” in four of them. Ten
  method descriptions on `SystemAdapter` and
  `Ggplot2ViolinLayerProcessor` that had been glued onto the previous
  method’s section have their own, and `find_graphics_plot_grob` has its
  own title rather than its file’s. Every public R6 method is
  documented, so `roxygenise()` runs without a warning (there were 391);
  `tools/document.R` regenerates `man/` with the pinned roxygen2 release
  and fails on any warning, as does the `docs-drift` CI job, and the
  test suite rejects the roxygen layouts that produce a page describing
  the wrong object.
- The README lists every roadmap-added layer type under “Experimental
  Plot Types”, the examples gallery has a worked example for each Base R
  and ggplot2 chart, and `use_cdn` is documented as it behaves:
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) use the
  bundled files by default (with a `lib/` folder beside the saved file),
  while widgets, knitr and Shiny auto-detect the CDN.
- The getting-started vignette tells Quarto `revealjs` authors how to
  keep off-slide charts out of the tab order.
- The examples gallery on the package website is one article per plot
  family (bar and pie, distributions, scatter and line, heat map and
  candlestick, multi-panel and facet, and two Base R pages) linked from
  a short hub at the old URL, so each page stays well inside the 2 MB of
  HTML that Googlebot reads. The website also gains a `robots.txt`,
  canonical links, per-page descriptions, and cross-links to the MAIDR
  JavaScript core and py-maidr.
- `citation("maidr")` returns the CHI 2024 and EuroVis 2024 MAIDR papers
  alongside the package entry (new `inst/CITATION`), and the README
  cites them.
- The “Getting Help” sections of the getting-started and Shiny vignettes
  send bug reports to this package’s issue tracker rather than the
  JavaScript core’s, with link text that names the repository, and the
  README’s help section points at the function reference instead of back
  at the site it is on
  ([\#311](https://github.com/xability/r-maidr/issues/311)).
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) is no
  longer described as writing a “standalone” or “portable” file. By
  default the MAIDR.js library goes into a `lib/` folder beside the file
  and the two have to be shared together; an `.html` sent on its own
  loads no MAIDR.js and shows a plain chart. The description line, the
  README and the getting-started vignette now say so, and “standalone”
  is reserved for `use_cdn = TRUE`
  ([\#319](https://github.com/xability/r-maidr/issues/319)).
- The README and the getting-started vignette carry one section, “How
  maidr hooks into your session”, saying what happens at the console
  (printing a ggplot2 object opens the viewer; Base R calls are recorded
  until [`show()`](https://r.maidr.ai/reference/show.md)), in R Markdown
  and Quarto ([`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md)
  in a setup chunk, which installs the knitr hooks that
  [`library(maidr)`](https://github.com/xability/r-maidr) alone does
  not), in Shiny, and how to turn it off. The examples hub no longer
  implies that interception is off until
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) is called,
  [`?maidr_on`](https://r.maidr.ai/reference/maidr_on.md) says when the
  call is needed, and the reference index files
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md),
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) and
  [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md)
  under “Turning interception on and off” rather than under R Markdown
  alone ([\#318](https://github.com/xability/r-maidr/issues/318)).
- The README, the getting-started vignette and the examples hub carry
  one keyboard table, identical on all three and matched to the MAIDR
  core’s controls reference: Up/Down, layer switching with Page Up/Page
  Down, label mode, high contrast and the shortcut help are listed,
  Space is “repeat the current sound”, and the Enter/Space and Escape
  rows the vignette had, which the core does not bind, are gone. Each
  copy sits between markers and `tests/testthat/test-docs-key-table.R`
  fails when the three drift apart
  ([\#312](https://github.com/xability/r-maidr/issues/312)).
- What attaching maidr masks is documented for users.
  [`?"base-r-wrappers"`](https://r.maidr.ai/reference/base-r-wrappers.md),
  which every Base R autolink on the website already pointed at but
  which was hidden from the reference index and the search engines, is
  now a user-facing page listing the graphics, stats, base and methods
  functions maidr replaces, saying that each passes through to the
  original, that [`show()`](https://r.maidr.ai/reference/show.md) hands
  a non-plot object to
  [`methods::show()`](https://rdrr.io/r/methods/show.html) and that
  scripts and packages should call
  [`maidr::show()`](https://r.maidr.ai/reference/show.md) by name, and
  giving the attach order for vioplot, wordcloud and quantmod in one
  place. It is indexed under “What attaching maidr masks”, and the
  README and the getting-started vignette summarise it in their session
  section ([\#320](https://github.com/xability/r-maidr/issues/320)).
- Stable and experimental plot types can no longer be mistaken for each
  other. Outside the README’s definition tables, every experimental type
  named in a heading, list or table row of the example articles, the
  getting-started vignette,
  [`?maidr`](https://r.maidr.ai/reference/maidr-package.md),
  [`?maidr_gantt`](https://r.maidr.ai/reference/maidr_gantt.md),
  [`?maidr_roc`](https://r.maidr.ai/reference/maidr_roc.md) and the
  example scripts carries an **\[experimental\]** mark after its name,
  and an unmarked type is stable, the convention the MAIDR JavaScript
  core and py-maidr follow in their own docs. The README says so, and
  its stable table notes that ggplot2 contour and Base R
  [`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html)
  are experimental; the getting-started vignette gains an “Experimental
  Plot Types” section and lists Base R contour plots, and
  [`?maidr`](https://r.maidr.ai/reference/maidr-package.md) lists
  contour and candlestick charts.
- Stable and experimental plot types are no longer interleaved where the
  docs list them: the stable ones come first and the experimental ones
  follow in a section of their own. The examples hub splits its plot
  families into “Stable plot families” and “Experimental plot families”,
  the pkgdown Articles menu gives the two wholly experimental Base R
  pages a section of their own, and the getting-started vignette’s
  stable list no longer names ggplot2
  [`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html)
  or Base R
  [`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html),
  which its experimental list already covers. The README says so.

### Performance

- Charts are exported to SVG with ‘svglite’ instead of ‘gridSVG’.
  gridSVG walked every grob in R; svglite draws with R’s graphics engine
  in C++. The exported document keeps the shape maidr’s selectors and
  maidr.js are written against – the same element ids, groups, Y-flip,
  `<use>` points and presentation attributes – so highlighting,
  announcements and high-contrast mode are unchanged. Exporting is 3 to
  7 times faster (a 10,000-point ggplot2 scatter in 0.4 s rather than
  1.6 s, a 100 x 100 heat map in 0.5 s rather than 1.5 s, 2,000 segments
  in 2.2 s rather than 15 s), and the SVG is no larger, a little smaller
  for most charts.
  [`matplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md) charts,
  which gridSVG could not export and which fell back to a static image,
  are now interactive.
- Rendered SVGs no longer carry gridSVG’s inline `gridSVGCoords` and
  `gridSVGMappings` script blocks. Nothing in maidr.js or this package
  read them, and they made up about a quarter of every chart’s HTML, so
  [`show()`](https://r.maidr.ai/reference/show.md),
  [`save_html()`](https://r.maidr.ai/reference/save_html.md), knitr and
  Shiny output is correspondingly smaller.
- ggplot2 layer processors reuse one built plot and gtable per render,
  and the faceted and patchwork paths do the same per panel and leaf.
- Base R renders cache the replayed gtable instead of re-replaying every
  recorded call; candlestick SVG post-processing parses the document
  once; the bundled JS/CSS is read once per session.
- The chart data embedded in each SVG is serialised about ten times
  faster for layers with many points, with byte-identical output.
  `jsonlite` spent 2 s of a 5 s render on the per-point records of a
  10,000-point ggplot2 scatter; that render now takes 2.7 s, and a
  5,000-point line 0.9 s rather than 1.9 s.

## maidr 0.4.0

CRAN release: 2026-07-10

### New Features

- Added candlestick (OHLC) chart support for ‘ggplot2’ via the
  ‘tidyquant’ package’s
  [`geom_candlestick()`](https://business-science.github.io/tidyquant/reference/geom_chart.html).
  Each candle is exposed as a single navigable element with `open`,
  `high`, `low`, `close`, optional `volume`, and computed `trend` (Bull
  / Bear / Neutral) and `volatility` (high − low) fields.
- Added Base R candlestick (OHLC) chart support via
  `quantmod::chartSeries(x, type = "candlesticks")`. The xts/zoo input
  is validated with
  [`quantmod::has.OHLC()`](https://rdrr.io/pkg/quantmod/man/has.html)
  and each row is emitted as a navigable `CandlestickPoint` with `value`
  (ISO date), `open`, `high`, `low`, `close`, computed `trend` (Bull /
  Bear / Neutral) and `volatility` (high − low) fields, plus optional
  `volume` when
  [`quantmod::has.Vo()`](https://rdrr.io/pkg/quantmod/man/has.html) is
  `TRUE`.

## maidr 0.2.0

CRAN release: 2026-03-07

### New Features

- Added violin plot support for ‘ggplot2’
  ([`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)),
  including both vertical and horizontal orientations.
- Violin plots produce two interactive layers: a box-summary layer
  (`violin_box`) with min, Q1, median, Q3, max highlights, and a KDE
  density-curve layer (`violin_kde`) with navigable density points.
- Added Ramer-Douglas-Peucker (RDP) curve simplification to reduce KDE
  density points to ~30 per violin while preserving shape fidelity.
- SVG coordinate injection for violin KDE points enables accurate
  highlight positioning in the maidr frontend.

### Enhancements

- Renamed option `maidr.enabled` to `maidr.auto_show` for clarity.
- Added `domMapping.iqrDirection` support for violin box layers,
  aligning with the existing box plot pattern for correct Q1/Q3
  highlighting under gridSVG Y-flip transforms.
- Added plot augmentation API (`augment_plot()`, `needs_augmentation()`)
  to the `LayerProcessor` base class, enabling processors to inject
  additional geom layers before rendering.
- Added multi-layer expansion in the orchestrator for plot types that
  produce more than one maidr layer from a single geom.

### Documentation

- Added violin plot examples to
  [`show()`](https://r.maidr.ai/reference/show.md),
  [`save_html()`](https://r.maidr.ai/reference/save_html.md), vignettes,
  and example scripts.
- Updated DESCRIPTION to list violin plots as a supported type.

## maidr 0.1.1

Resubmission after CRAN archival. Fixes CRAN policy compliance issues.

### Bug Fixes

- Removed all `assign(..., envir = .GlobalEnv)` calls that violated CRAN
  policy. Base R function wrappers are now installed into the package
  namespace during `.onLoad` and controlled via an active/inactive flag,
  eliminating any modification of the user’s global environment.
- Removed [`attach()`](https://rdrr.io/r/base/attach.html) usage that
  produced R CMD check NOTE.
- Fixed Rd documentation warning caused by unicode escape sequences in
  `prefix_to_currency_code` parameter documentation.

### Enhancements

- Added subtitle and caption support to the MAIDR payload for both
  ‘ggplot2’ and Base R plots.
- Added `scales` formatting support for Base R axis labels (currency,
  percent, comma, scientific notation).

## maidr 0.1.0

Initial CRAN release.

### Features

- [`show()`](https://r.maidr.ai/reference/show.md) - Display
  interactive, accessible visualizations from ggplot2 or Base R plots
  with keyboard navigation and screen reader support
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) - Export
  accessible visualizations to standalone HTML files
- [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) and
  [`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md) -
  Shiny integration for interactive web applications

### Supported Plot Types

#### ggplot2 - Basic

- Bar charts
  ([`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html),
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html))
- Grouped/dodged bar charts (`position = "dodge"`)
- Stacked bar charts (`position = "stack"`)
- Histograms
  ([`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html))
- Line plots
  ([`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html))
- Scatter plots
  ([`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html))
- Box plots
  ([`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html))
- Heatmaps
  ([`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html))
- Smooth/density curves
  ([`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html),
  [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html))

#### ggplot2 - Advanced

- Faceted plots
  ([`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html),
  [`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html))
- Multi-panel layouts with patchwork package
- Multi-layered plots (e.g., histogram + density, scatter + smooth)

#### Base R - Basic

- Bar plots
  ([`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md))
- Grouped bar plots (`beside = TRUE`)
- Stacked bar plots (`beside = FALSE`)
- Histograms
  ([`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md))
- Line plots
  ([`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
  `type = "l"`,
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md))
- Scatter plots
  ([`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md))
- Box plots
  ([`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md))
- Heatmaps
  ([`image()`](https://r.maidr.ai/reference/base-r-wrappers.md))
- Density curves (`lines(density())`)

#### Base R - Advanced

- Multi-panel plots (`par(mfrow)`, `par(mfcol)`)
- Faceted-style plots (using
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md) with loops)
- Multi-layered plots (sequential plotting calls)

### Accessibility Features

- Keyboard navigation for data exploration
- Screen reader compatibility with ARIA labels
- Sonification (audio representation of data)
- Multiple sensory modalities for data access
