# Changelog

## maidr (development version)

### New Features

- Base R
  [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  is now read as the contour it draws, instead of falling back to a
  static image. It draws the same level curves
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
  and fills the bands between them, so both spellings of one chart now
  get one reading, and the curves come from
  [`grDevices::contourLines()`](https://rdrr.io/r/grDevices/contourLines.html)
  – the computation the drawing itself runs – rather than from anything
  inferred about the fill.

  Two things differ from
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md). Its
  level default is twice as large (`nlevels = 20` against 10), which
  decides the whole announced set through `pretty(zlim, nlevels)`;
  everything else about resolving the call is identical in the two
  functions and is shared rather than copied.

  And the chart carries no highlight.
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
  one `lines` grob per curve; `filled.contour` writes one `polygon` grob
  for the whole field, and measured on a 6x5 grid at the 17 default
  levels it exports 160 pieces against 40 curves – the grid’s cells cut
  by the level crossings, neither the bands nor the curves. Nothing
  pairs, so no selector is emitted: the chart is announced, sonified and
  navigated, and only the visual highlight is missing, which is a better
  answer than a picture that offers none of them.

- Base R
  [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
  now read as the one-dimensional scatter it draws, instead of falling
  back to a static image. Every observation is announced as its own
  mark, laid along a value axis at its group’s position, with the
  group’s name carried beside it.

  **One layer per group**, which the drawing decides rather than
  tidiness: gridGraphics exports one `points` grob per group, and the
  grob lookup answers with the first match, so a single layer would
  announce all the observations and highlight only the first group’s. It
  is also the reading the same chart already gets in py-maidr.

  The groups are not re-derived.
  [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  forms them in two places – a list or a bare vector in
  `stripchart.default`, and
  [`split()`](https://rdrr.io/r/base/split.html) after
  [`stats::model.frame()`](https://rdrr.io/r/stats/model.frame.html) in
  `stripchart.formula` – and both are called rather than imitated, so
  `group.names`, `at` and a formula’s own splitting all behave as the
  chart drew them. `vertical = TRUE` swaps which visual axis holds the
  values, and the axes are named for what they hold, the same way
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) already
  name theirs.

  `method = "jitter"` needs no special handling here, unlike
  [`geom_jitter()`](https://ggplot2.tidyverse.org/reference/geom_jitter.html)
  ([\#174](https://github.com/xability/r-maidr/issues/174)): a
  stripchart jitters along the *group* axis only, so every number
  announced is the observation itself, and what is displaced is a
  position whose name travels with it as a label.

- Base R [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  and [`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) are
  now read as the quantile scatter they draw, instead of falling back to
  a static image.

  What separates a Q-Q plot from every other base R scatter is that its
  coordinates are **computed rather than handed in**. `qqnorm(y)` takes
  one sample and draws it against theoretical quantiles it works out;
  `qqplot(x, y)` takes two samples of possibly different lengths and
  draws one interpolated pair per point of the shorter. Read as an
  ordinary scatter, both would have announced numbers no mark on the
  page stands for – for `qqnorm`, the raw sample on an axis of standard
  deviations, which is the one reading a Q-Q plot most needs not to
  have.

  So the coordinates are not re-derived: `stats` is asked for them with
  `plot.it = FALSE`, which returns exactly what the plotted call would
  have drawn, and the recorded arguments are forwarded whole.
  `datax = TRUE` therefore swaps the axes – and their labels – without
  anything in maidr knowing the argument exists.
  [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s own
  “Normal Q-Q Plot”, “Theoretical Quantiles” and “Sample Quantiles” are
  announced because they are constants it draws;
  [`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)’s
  defaults are the caller’s own expressions, which are gone by the time
  the call is recorded, so its axes are left for the renderer’s generic
  rather than guessed at.

  Two shapes are still pictures, deliberately. `qqplot(conf.level = )`
  draws a confidence band as well as the points, and
  [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws
  the reference line nearly every Q-Q plot is finished with; both reach
  `graphics` from inside `stats`, where maidr never sees them, and
  neither has anywhere to go in the payload. Reading the points alone
  would have handed a reader a chart with a drawn mark silently missing
  from it, which is worse than the picture, so
  [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md) is now
  recorded purely so that it can be declined.

- A Base R
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
  now read as the contingency table it draws, instead of falling back to
  a static image. What separates a mosaic from a stacked bar is that the
  **column widths encode data too** – each column’s width is that
  category’s share of all observations – so a reader given only the
  segment heights has half the table: the conditional proportions
  without the group sizes they were computed from, which makes a
  category of six observations and one of six hundred read identically.

  Nothing is inferred from the drawing.
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
  handed the table itself, so the recorded call carries the counts, the
  margins they imply, and the level names from
  [`dimnames()`](https://rdrr.io/r/base/dimnames.html). Each cell
  announces four numbers: its conditional proportion within its column,
  its column’s share of the whole, its own count, and its fill level.
  Each tile is addressable on its own – gridGraphics writes one
  `polygon` grob per cell, down each column with the columns left to
  right.

  The two dimension names go where the grammar puts them rather than
  where the chart draws them:
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  labels its y axis with the second dimension, but a segmented layer’s
  `y` holds the magnitude and its `z` the fill, so the second dimension
  is announced as the fill and `y` says its numbers are proportions.

  Two limitations worth knowing. A table of three dimensions or more is
  still a picture:
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  splits recursively and a `mosaic` layer has one category axis and one
  fill, so a deeper table has nowhere to put its later dimensions. And
  the formula interface – `mosaicplot(~ Hair + Eye, data = df)` – is a
  picture too, because the recorded call carries the formula rather than
  a table.

### Bug Fixes

- A layer of a **recognised** type that drew nothing no longer reaches
  the schema. [\#227](https://github.com/xability/r-maidr/issues/227)
  stopped an *unclaimed* empty layer from costing the chart its
  interactivity; a layer typed on its geom got no such question, so it
  was classified, a processor was built for it, and a reader was handed
  a layer to walk into with nothing in it. Measured on ten points, the
  second layer drawn from `d[0, ]`:

      geom_point()   point(10) point(0)      an empty layer of points
      geom_col()     point(10) bar(0)        an empty layer of bars
      geom_line()    point(10) line(1x0)     one series, holding nothing
      geom_smooth()  point(10) smooth(1x0)   one series, holding nothing

  The two series cases are the worse ones: a reader is offered something
  to walk into. The issue named the point and smooth spellings; the line
  and bar ones were found on the way and are the same absence read two
  more ways.

  Asked once per chart in the orchestrator, not per layer in the
  classifier. That is what made this affordable – an emptiness check at
  the top of `detect_layer_type()` would have made every chart pay one
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  *per layer*, which is why
  [\#231](https://github.com/xability/r-maidr/issues/231) applied it to
  one geom only. Measured on a 5,000-point two-layer chart: 3.38 s
  against 3.22 s, one build of 0.14 s, and the same 0.14 s however many
  layers the chart has.

  It is also the right place on its own terms. Emptiness is not a fact
  about what *kind* of chart a layer is, so `detect_layer_type()` still
  answers `point` for an empty
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  and the orchestrator is what decides there is nothing to make a
  processor for.

  A plot whose *only* layer is empty falls back to an image. The layer
  is tagged `skip`, which is the tag the
  [\#176](https://github.com/xability/r-maidr/issues/176) guard already
  reads: a chart announcing itself as interactive with nothing in it is
  worse than an image, because an image at least says what it is.

  Composed and faceted charts get the same answer. A `patchwork` leaf is
  classified without ever passing through the orchestrator, so the rule
  is stated once as
  [`layers_that_drew_nothing()`](https://r.maidr.ai/reference/layers_that_drew_nothing.md)
  and asked per leaf as well – a rule written only in the orchestrator
  would have left every composed chart ghosting while every plain one
  stopped. Faceting already went through the orchestrator and is pinned
  so it stays that way.

- The smooth processor no longer answers “which layer do I read?” with
  *somebody else’s*. When a layer’s own geom was one it could not read,
  it searched the plot’s other layers for one drawing a curve and
  returned that index – so a bar layer beside a
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  came back with the smooth’s fitted values as its own data, announcing
  one layer’s fit as another’s.

  Unreachable through the dispatch since the previous release, which
  made the classifier consult
  [`smooth_reads_geom()`](https://r.maidr.ai/reference/smooth_reads_geom.md)
  before typing a layer `smooth`, so the processor is only ever built
  for a layer it can read. Measured before removing it, instrumented on
  the full suite: the search was entered three times, every one of them
  from a unit test handing the processor a bar plot by hand. No render
  reached it.

  It also carried a fourth thing worth losing – its own list of four
  geoms, a third copy beside
  [`smooth_reads_geom()`](https://r.maidr.ai/reference/smooth_reads_geom.md)’s
  six and the dispatch’s, which would have needed a matching edit each
  time the shared list grew. Widening it to match would have been the
  wrong repair: the wider that list, the more often the search
  *succeeds*, and succeeding is the failure mode.

  A caller who constructs the processor against a layer it cannot read
  now gets told so, and told which geom it was.

- A layer whose stat says “smooth” but whose geom the smooth processor
  cannot read no longer stops the render.
  [`stat_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  was claimed on its stat, and a stat can name a geom the processor does
  not recognise – `stat_function(fun = sin, geom = "point")` was one.
  The processor then rejected the layer’s own index, found nothing in
  its fallback search and
  [`stop()`](https://rdrr.io/r/base/stop.html)ped, so
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) raised
  `No smooth curve layers found in plot` and the caller’s script ended.
  Which geom the author happened to pass decided whether the call
  returned at all:

  ``` r

  stat_function(fun = sin, geom = "point")  # Error out of save_html()
  stat_function(fun = sin, geom = "step")   # Error out of save_html()
  stat_function(fun = sin)                  # interactive
  ```

  A decline is a reading decision; an exception is a broken call. The
  list the processor works from is now stated once, as
  [`smooth_reads_geom()`](https://r.maidr.ai/reference/smooth_reads_geom.md),
  and the classifier consults it before claiming a layer, so the two
  cannot disagree. A function drawn as points now falls through to the
  point branch and reads as the scatter on the page; drawn as steps it
  reaches the unknown processor and the chart falls back to an image,
  which is the step branch’s documented answer for a step drawn on some
  other computed stat. Both render.

  This is why `StatQuantile` was left out beside `StatDensity` in the
  previous release: a stat check would have made
  `stat_quantile(geom = "point")` a second instance of exactly this
  crash. With the guard in place it is no longer needed – what a stat
  check buys is the spellings where the geom says nothing, and those are
  now turned away when the processor cannot read them.

- [`geom_quantile()`](https://ggplot2.tidyverse.org/reference/geom_quantile.html)
  is now read as the fitted curve it draws, instead of costing its chart
  every bit of interactivity. `GeomQuantile` is a `GeomPath` subclass
  and dispatch matches the first class name, so it matched no branch and
  reached the unknown processor – the third geom missed this way, after
  [`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  and
  [`geom_spoke()`](https://ggplot2.tidyverse.org/reference/geom_spoke.html).
  Measured on thirty points, a scatter went from a 50,409 byte
  interactive SVG to a 44,724 byte base64 image the moment a quantile
  fit was drawn beside it, while the *mean* fit beside the same points
  read fine.

  It reads as a `smooth` rather than a `line` for the reason
  [`stat_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  does:
  [`stat_quantile()`](https://ggplot2.tidyverse.org/reference/geom_quantile.html)
  fits `rq`/`rqss` and evaluates it at renderer-chosen positions exactly
  as
  [`stat_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  does for the conditional mean, so the curve is a model over the data
  rather than a series of it.

  Keyed on the geom alone. The symmetric `StatQuantile` addition would
  have made `stat_quantile(geom = "point")` a second instance of an
  existing crash, which is reported separately rather than matched.

  A quantile layer that drew *nothing* keeps the answer it had before:
  skipped, not claimed.
  [`geom_quantile()`](https://ggplot2.tidyverse.org/reference/geom_quantile.html)
  without **quantreg** computes no rows, and it is the case that rule
  was written for, so claiming it on the geom regardless would have put
  an empty layer in the schema for a chart that had none.

- A layer that drew **nothing** no longer costs the whole chart its
  interactivity. An unclaimed layer makes the plot fall back to a static
  image, which is right when the layer put a mark on the page that
  nothing describes – a reader told the chart was complete would be told
  wrong – and wrong when it drew nothing at all, because then there is
  no mark and the chart pays everything to protect the reader from an
  absence. Measured on thirty points,
  `geom_point() + geom_polygon(data = frame[0, ])` was a 27,368 byte
  base64 image where `geom_point() + geom_point(data = frame[0, ])` was
  a 51,313 byte interactive SVG: the same chart in every way a reader
  could tell, and only one of them accessible, because one empty layer
  happened to be of a *kind* the adapter names.

  The case this turns up in is a missing **Suggests** package.
  [`geom_quantile()`](https://ggplot2.tidyverse.org/reference/geom_quantile.html)
  without **quantreg** warns, computes no rows and draws nothing;
  ggplot2 carries on and the figure silently stopped being accessible,
  with no second warning connecting the two.

  Nothing here changes which geoms are readable. A
  [`geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
  with data in it is still declined and still costs its chart exactly
  what it cost before, and a plot made only of empty unclaimed layers
  still falls back rather than announcing itself as an interactive chart
  with nothing in it.

### New Features

- [`geom_spoke()`](https://ggplot2.tidyverse.org/reference/geom_spoke.html)
  is now read as the gantt chart it draws, where it draws one. A spoke
  is
  [`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
  reparameterised – an angle and a radius rather than an endpoint – and
  ggplot2 turns the pair into the same `xend`/`yend` the segment reading
  already uses, so the two spellings of one mark now reach one rule and
  answer it alike. A flat spoke is a lane per `y` running from `x` to
  `x + radius`; an angled one is a vector field rather than a schedule
  and is still declined, exactly as the segment spelling of the same
  chart would be. What this fixes is what a decline used to cost: an
  unclaimed layer makes the whole plot fall back to a static image, so a
  thirty-point scatter with a spoke layer beside it went from an
  interactive SVG to a base64 image and lost every one of its points.

  A gantt layer now counts its position among the layers drawing the
  same **grob class** rather than among layers of the same geom, which
  is the population the grob list it indexes into was gathered by. The
  two were the same set until a spoke joined
  [`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
  in drawing a `segments` grob: a chart with one layer of each gave both
  `position == 1`, so they resolved to the same grob and the second
  highlighted the first’s intervals while announcing its own.
  [`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
  never collided, because it draws a `curve` grob instead.

- A Base R
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) is now
  read as the contour it draws, instead of falling back to a static
  image. The curves come from
  [`grDevices::contourLines()`](https://rdrr.io/r/grDevices/contourLines.html),
  which is the computation
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) itself
  does and takes the same defaults –
  `x = seq(0, 1, length.out = nrow(z))`, `levels = pretty(range(z), 10)`
  – so the announced levels are the drawn ones rather than a plausible
  set. Each curve is addressable on its own: gridGraphics writes one
  `lines` grob per curve, in the order
  [`contourLines()`](https://rdrr.io/r/grDevices/contourLines.html)
  returns them, so highlighting follows a reader from curve to curve.
  The payload matches what the ggplot2 side emits for
  [`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html),
  so the two adapters describe one chart alike. This completes the work
  begun when
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md) was
  made to degrade safely: it had been shipping a layer type the frontend
  could not construct, which left the figure interactive-looking and
  unusable, and the interim fix was a picture. A limitation worth
  knowing: gridGraphics cannot emulate the inline level labels drawn
  along the curves, which costs nothing here since each point carries
  its own level.

### Bug Fixes

- Eight Base R plotting calls stopped
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) outright
  instead of falling back to a picture:
  [`persp()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`sunflowerplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md).
  None of them was in maidr’s function classification, so no wrapper was
  installed and the call was never recorded; the device then looked
  empty and the save reported “No Base R plots detected. Please create a
  plot first” – to a caller whose chart was on the device. All eight are
  now recorded and take the same static-image path
  [`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  already take, with the usual “unsupported elements” warning. Being
  recorded is not a claim that the chart is read; it is what stops an
  unread chart from costing the save. `qqnorm(x, plot.it = FALSE)` and
  `qqplot(x, y, plot.it = FALSE)` compute without drawing and are still
  not recorded, alongside the `plot = FALSE` spelling
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) use.

- The chart could still strand a reader in a Shiny app. Handing focus
  back to the page assumed that asking an element to take it worked, and
  an element with no rendered box refuses silently – Shiny wraps every
  output in a `display: contents` div, and a chart’s frame sits directly
  inside one. The page now reads the outcome back and walks on up the
  ancestors until one actually takes focus, leaving no `tabindex` behind
  on the ones that refuse. The tab stop before the frame is checked the
  same way, since one of those can be a `display: contents` element too,
  and every candidate is asked as it stands before being given a
  `tabindex` — so a tab stop the page already owns is never taken out of
  its own tab order.

- A chart in a Quarto `revealjs` slide swallowed every key, with no way
  back to the deck. Charts are embedded in an iframe, and keyboard
  events do not cross a frame boundary, so while a reader is inside a
  chart the slide around it hears nothing – which is right while they
  are reading, since MAIDR binds the arrows, Space and Page Up/Down
  itself, and leaves Shift+Tab as the way out. But a deck renders no
  controls of its own, so a chart is the first thing on the page and
  there is nothing before it to receive focus: Shift+Tab left the
  document altogether for the browser’s own UI, and from that moment
  neither Space for the next slide nor the arrows for the previous one
  reached the deck. The parent-side listener each chart already installs
  now also answers the chart’s request to hand focus back, putting it on
  the slide, where the deck’s own shortcuts work again. It steps in only
  where the browser would have stranded the reader, so a chart in an
  article or a notebook keeps the tab order it had, and it now runs on
  the [`maidr_widget()`](https://r.maidr.ai/reference/maidr_widget.md)
  path too.

### New Features

- [`geom_contour()`](https://ggplot2.tidyverse.org/reference/geom_contour.html)
  and
  [`geom_density_2d()`](https://ggplot2.tidyverse.org/reference/geom_density_2d.html)
  are now read as contour layers. A contour draws a scalar field as
  curves of constant value, and this is the one chart of its family
  whose value is a **number rather than a colour**:
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  puts `level` on every row. ggplot2 has also already split the curves –
  a field with two peaks crosses a level twice and arrives as two
  `piece`s – so each island is announced as its own curve rather than
  the two being joined by a line the field never took. The **filled**
  forms are not this chart and are declined: they draw the bands
  *between* levels, and their `level` is a factor of intervals rather
  than a number, which the reader checks in the frame as well as in the
  geom’s name.

- [`geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
  is now read as a gantt chart. A segment with the two ends of a span on
  one axis and a lane on the other is how ggplot2 draws a schedule, a
  range plot and a high-low chart, and it was read as nothing at all.
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  computes the interval and the lane exactly – `x`, `xend`, `y`, `yend`
  – and the panel’s scale names the lanes at the positions the built
  data records, so nothing is inverted from a pixel. A lane booked twice
  keeps both intervals under one row, and a level nothing was drawn in
  survives `scale_y_discrete(drop = FALSE)` as the empty row it is. Both
  orientations work. A layer whose segments share no coordinate is a
  node-link diagram’s edges and keeps the static-image fallback it had,
  asked of the whole layer so that a chart holding both is not announced
  as a gantt missing part of itself.
  [`geom_curve()`](https://ggplot2.tidyverse.org/reference/geom_segment.html)
  computes the same columns but is **not** read: gridSVG cannot export
  the `curve` grob it draws, so claiming it would turn a chart that
  renders into a
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) that
  raises.

- [`stat_ecdf()`](https://ggplot2.tidyverse.org/reference/stat_ecdf.html)
  is now read as a step layer. An empirical CDF previously detected as
  `unknown` and fell back to the static image, announcing nothing at
  all, even though `step` was already supported. It had been declined on
  purpose: `StatEcdf` returns its rows in input order – `GeomStep` only
  sorts them later, inside `draw_panel()` – and pads them with
  `-Inf`/`Inf` for the two ends of the staircase, so the rows as built
  matched neither the drawn polyline nor any announceable x. Both are
  now undone before the frame is read. The sort is not an imposed order:
  `stairstep()` opens by ordering on `x`, so the sorted rows are what is
  actually drawn. A grouped `stat_ecdf(aes(colour = g))` becomes one
  staircase per group, ordered within each. A step layer on any other
  computed stat still declines rather than being read on a guess.

- [`geom_ribbon()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  is now read rather than dropped. It is the other way to draw a
  confidence band – and the one a user gets assembling
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)’s
  two halves by hand – but it fell through to the unknown-layer
  processor, so the interval was lost. It is not automatically an
  interval, though: `geom_ribbon(aes(ymin = 0, ymax = y))` is an area
  chart, and announcing that as an uncertainty would report a filled
  magnitude as a bound. The baseline separates the two, which is the
  same rule the Python binding draws for `fill_between()`: filling from
  zero to one curve is an area, and anything else is the gap between two
  curves.
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  is untouched – it inherits `GeomRibbon`, so the rule is a first-class
  check rather than an [`inherits()`](https://rdrr.io/r/base/class.html)
  one.

- [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  now keeps the confidence band it draws. `se = TRUE` is the default,
  and the band is the reason the layer is drawn rather than a plain
  line: it says how much of the fitted trend the data supports.
  `StatSmooth` computes it into `ymin`/`ymax` alongside the fitted
  value, and maidr read only the fit – so a chart that otherwise worked
  was silently missing the half a reader needs to judge it. The bounds
  ride on the fitted samples as `yMin`/`yMax`, so a value and its
  interval are heard at one x rather than by switching layers. A density
  curve is left alone – `StatDensity` fills the same two columns with
  the extent of its fill rather than an uncertainty, so the rule asks
  the layer’s stat rather than its columns.

- A faceted
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  keeps its confidence band. The band was emitted as a separate
  `error_bar` layer at first, because that was the only shape the
  frontend read, and a facet panel carries a single layer type by
  construction – so a guard suppressed the band on a faceted chart
  rather than lose the fitted curve along with it. maidr 4.3.0 reads the
  bounds on the curve’s own points, which leaves no second layer to
  lose. Measured across the change: a faceted `geom_smooth(se = TRUE)`
  went from 0 samples carrying bounds per panel to all 80. Two other
  pieces of scaffolding went with the second layer – the per-curve
  `name` that told two band layers apart, and the empty selector list
  that said a ribbon has no per-sample element to highlight.

- Violin plot support for base R.
  [`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html)
  is now emitted as the `violin_box` + `violin_kde` layer pair the
  ‘ggplot2’ adapter already produces for
  [`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html),
  so which plotting system a user chose no longer decides whether their
  chart is accessible.
  [`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) returns
  its box summary but not the density curve it drew, so maidr recovers
  both by replaying the
  [`sm::sm.density()`](https://rdrr.io/pkg/sm/man/sm.density.html) call
  vioplot makes internally – the same approach the base R box plot
  processor takes when it re-calls `boxplot(plot = FALSE)`. That
  distinction matters: a kernel density estimate computed with different
  defaults is not wrong in any way a reader could detect, it simply
  describes a shape the chart does not draw. Both halves are checked
  against the drawing rather than assumed – the box statistics come back
  identical to vioplot’s own return value, and the drawn violin body
  carries exactly twice as many vertices as `sm.density()` returns
  evaluation points, being that curve mirrored. A caller’s `h` and
  `range` are carried through rather than defaulted, since the first
  decides how smooth the announced curve is and the second where the
  whiskers stop. A category whose values are all equal has no
  distribution to describe and is left out rather than given an invented
  spread, and a formula call is declined rather than guessed at, since
  resolving it needs an environment the processor no longer has.

- Base R violin sections highlight the element that draws them. vioplot
  draws the whisker, the quartile box and the median as separate grobs,
  so unlike a chart whose box is a single path, each section points at
  its own mark.

- Area chart support for ‘ggplot2’.
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  is now emitted as an `area`, `stacked_area` or
  `stacked_normalized_area` layer rather than falling through
  unclassified, so an area chart carries data at all – and the stacked
  variants keep two numbers apart that a line layer would conflate: the
  band’s *height* is the series’ own value while its *top edge* is the
  running total, and the reader is told which is which. Two things about
  ‘ggplot2’’s computed data make this easy to read wrongly and both are
  silent: the `y` column is the cumulative top rather than the value,
  and
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  defaults to `stat = "align"`, whose interpolation and baseline-closing
  vertices outnumber the observations three to one – so a four-year
  chart would otherwise announce twelve points per series, including a
  reading at “year 2000.003”. Only the rows whose x the layer was given
  are described. A filled area (`position = "fill"`) is distinguished
  for the same reason a filled bar is, and `geom_area(stat = "density")`
  keeps being read as the smooth it is.

- Area layers highlight the band under the cursor.
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  draws each series as its own ribbon holding a filled polygon, which is
  exactly the granularity the consumer needs – one selector per series,
  since the area trace extends the line trace and discards a selector
  list whose length disagrees with the data. The existing curve
  machinery could not supply it: it counts curves inside one auto-named
  polyline grob and deliberately skips geom-named trees, an area layer
  being the shape that rule excludes. A count that does not match the
  data withdraws the selectors entirely rather than emitting a short
  list, because a highlight on the neighbouring band tells a reader the
  wrong thing about every value it announces, and only an absence is
  distinguishable from a correct list.

- Error bar support for ‘ggplot2’.
  [`geom_errorbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
  [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
  [`geom_linerange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html),
  [`geom_pointrange()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  and
  [`geom_crossbar()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  are now emitted as `error_bar` layers rather than falling through
  unclassified, so the interval a chart draws is navigable instead of
  silently dropped – and the interval is usually the finding, since
  whether two group means differ is answered by whether theirs overlap.
  The bounds are read from the pair the layer’s orientation says is the
  interval: ‘ggplot2’ computes *both* pairs for most of these geoms, and
  on a vertical layer `xmin`/`xmax` are the cap width, a styling
  parameter rather than data. Horizontal layers are recognised both ways
  ‘ggplot2’ records them, since
  [`geom_errorbarh()`](https://ggplot2.tidyverse.org/reference/geom_linerange.html)
  carries no `flipped_aes` column to read. The estimate aesthetic is
  optional throughout: `geom_errorbar(aes(x, ymin, ymax))` over a
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  is idiomatic and builds with no `y` column, so such a layer reports
  the centre of the drawn span rather than being dropped.

- 100% stacked bar support for ‘ggplot2’. A bar layer drawn with
  `position = "fill"` is now emitted as `stacked_normalized_bar` rather
  than being classified alongside `position = "stack"`. Filling rescales
  every category to a common height, so a segment’s value is its *share*
  of that category and every bar totals 1 by construction; read as a
  plain stacked bar those shares were announced as counts, implying the
  categories had equal totals — the one thing a filled bar is drawn to
  deny. The emitted values now follow the type: a filled layer reports
  the drawn share rather than
  [`stat_count()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)’s
  untouched `count` column or the pre-rescale `y` from the user’s own
  data frame.

- 100% stacked bar support for Base R.
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes
  no normalisation argument at all — the idiomatic 100% stacked bar is
  written by normalising the matrix first, as
  `barplot(prop.table(m, 2))` — so the classification reads the drawn
  geometry instead: a stacked barplot whose every column sums to 1 is
  emitted as `stacked_normalized_bar`. Deliberately narrow, and it
  claims nothing it cannot read. Columns summing to 100 stay a plain
  stacked bar, because a matrix of counts can total 100 by coincidence
  and the drawing does not distinguish that from percentages; a
  single-row matrix stays one too, since a series stacked against
  nothing is not a stack. The values need no adjustment here, unlike the
  ‘ggplot2’ case above: they already are the drawn shares.

- Added step plot support for ‘ggplot2’
  ([`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html))
  and Base R (`plot(type = "s")`, `plot(type = "S")`, and the
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  equivalents). A step plot describes a value that is piecewise constant
  — held across an interval and then jumped — such as the sleep stage of
  a hypnogram.

- Step layers emit one data point per data sample, never one per
  stairstep vertex, and report the layer’s step convention as
  `stepDirection` (`"hv"` / `"vh"` / `"mid"` from
  `geom_step(direction = )`; `"hv"` for Base R `type = "s"` and `"vh"`
  for `type = "S"`).

- When a step layer’s y aesthetic is an ordinal factor, each point
  carries the level *name* as `label`, so the frontend announces “REM”
  rather than the numeric level code while `y` stays numeric for
  sonification, braille and the min/max range.

- Pie chart support for both plotting systems. In ‘ggplot2’ a
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  /
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  layer drawn under `coord_polar("y")` — or `coord_radial(theta = "y")`
  — is now recognised as a pie rather than mis-read as a stacked bar;
  `coord_polar("x")`, which draws a coxcomb, keeps its bar behaviour. So
  does a multi-ring “bullseye” — `geom_col(aes(x = category))` under
  `coord_polar("y")` draws one concentric ring per x category, which a
  flat list of slices cannot describe. In Base R,
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) is
  described directly. Each wedge is one navigable slice carrying its
  label and its magnitude, and MAIDR derives the percentage from those
  values.

- Base R [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  charts can be exported at all. `gridGraphics` translates the wedge
  labels into text grobs whose `vjust` is `NA`, and gridSVG branches on
  that value directly, so `grid.export()` aborted with “missing value
  where TRUE/FALSE needed” and no
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) call could
  be rendered. Text grobs with an NA justification are now repaired to
  the value grid resolves them to anyway, which leaves the drawn output
  unchanged and every other plot type untouched.

### Bug Fixes

- ggplot2: a curve layer outlined whatever was drawn after it. A
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  or
  [`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html)
  picked its curve by taking the largest `GRID.polyline.N` in the panel,
  on reasoning that holds within one smooth layer – ggplot2 draws the
  confidence band before the fitted line, so the later grob is the line
  – but was applied across the whole panel, where the largest counter is
  simply whatever was drawn last. A
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  placed after the curve owned it, so the curve highlighted the line.
  The line highlighted the curve back when the curve was a
  [`geom_function()`](https://ggplot2.tidyverse.org/reference/geom_function.html):
  `GeomFunction` inherits `GeomPath$draw_panel()` and so draws a *bare*
  polyline with no geom-named tree around it, which put it in the
  candidate list a line layer indexes into while the counter behind that
  index did not know it existed. Each layer now asks which grob it drew
  rather than guessing from the counter – the last polyline inside its
  own tree when it has one, and its draw-order position among the bare
  polylines when it does not. Nothing about either announcement changed
  in any of these cases: the audio, the text and the braille were
  correct throughout while the wrong curve lit up, which is why no
  assertion about the reading could see it.

- base R: a horizontal stacked or dodged bar chart was announced as a
  vertical one. `barplot(m, horiz = TRUE)` and
  `barplot(m, beside = TRUE, horiz = TRUE)` emitted no `orientation` key
  and left their points in the vertical arrangement, so the core read a
  chart drawn across the page as one drawn up it. Unlike the ggplot2
  case below, nothing was lost: base R has no flipped aesthetics to
  misread, its processors read the caller’s matrix directly, and a
  `vert` key over a vertical payload is self-consistent — the magnitudes
  announced were the right ones. What was wrong is everything that
  depends on knowing which way the chart is drawn. The chart type was
  announced as *vertical stacked bar plot*, and the stereo cue swept
  left-to-right as the reader moved through categories that run down the
  page, so sound and highlight disagreed about where the reader was.
  Both halves now move together, from one reading of the `horiz`
  argument: setting the key without swapping the points would have
  turned a wrong announcement into a chart with no magnitude at all.
  `barplot(h, horiz = TRUE)` on a plain vector was already correct and
  is untouched — that processor reads the drawn rectangles rather than
  the input, so its points arrive swapped without a swap step.

- ggplot2: a horizontal grouped bar chart came out with no data in it.
  `ggplot(df, aes(n, g, fill = h)) + geom_col(position = "dodge")` is
  the ordinary spelling, and neither the dodged nor the stacked
  processor ever asked whether its layer was `flipped_aes` – the
  question the plain bar processor learned to ask, and the string
  appeared in neither file. So the category names went into the level
  ordering as if they were the measure, and the measures went into
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) as if they were
  the categories. A chart of apple/banana/cherry against two fill groups
  came back as six columns per series, named after the chart’s own
  numbers and sorted by them, with every magnitude `null`: a chart that
  loads, navigates and announces “missing” at each of six categories
  that do not exist. A stacked layer had a category *name* sitting in
  the slot the magnitude is read from, and a `position = "fill"` layer
  took its category names from the computed proportions – “0.00”,
  “0.25”, “0.50” – because it reads its break labels off the panel’s x
  scale, and a horizontal layer breaks its categories on y. None of the
  three emitted an `orientation` key at all, so even correct data would
  have been read as a vertical chart. All three now unflip up front and
  swap the pair at the emit boundary, with the key and the layout taken
  from one answer so they cannot drift apart. The three unflip helpers
  and the emit swap moved to `LayerProcessor`, since four processors now
  need them.

- ggplot2: a horizontal bar chart announced no magnitude, and named its
  axes against the wrong halves of the data.
  `ggplot(df, aes(n, g)) + geom_col()` was emitted as
  `x = category, y = measure` – the vertical arrangement – while
  declaring `orientation: "horz"`. MAIDR reads a horizontal bar the
  other way round, taking `x` as the magnitude when the orientation says
  `horz`, so it went looking for a number and found a category name. A
  chart of apple = 30, banana = 70, cherry = 50 sounded with a `null`
  magnitude on every bar, and announced the point as `g: 30` with value
  `n: apple`: the category axis named against the measure and the
  measure axis against the category name. As with the first form of this
  bug, the `axes` block was right throughout – it said which way round
  the chart was drawn while the data underneath contradicted it. Fixed
  by exchanging the pair at the emit boundary, where a layer stops being
  this package’s internal representation and becomes MAIDR JSON; the key
  and the layout are now taken from one `is_flipped()` answer, so they
  cannot drift apart. The swap belongs to the bar grammar specifically
  and is not applied to every horizontal layer: an error bar keeps its
  category in `x` at both orientations and lets `orientation` swap only
  which axis labels the reading is announced against, and a box carries
  quantiles with no axis assignment to exchange.
  [`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
  is untouched – it leaves `flipped_aes` alone, so it is still reported
  `vert` with the vertical arrangement, which reads correctly.

- ggplot2: a faceted categorical scatter put a string where the grammar
  wants a number. The same chart emitted two different shapes depending
  on whether it was facetted – `ggplot(df, aes(g, v)) + geom_jitter()`
  gave `x = 1`, and adding `facet_wrap(~f)` gave `x = "a"` – because the
  faceted path indexed the panel’s sorted category values by the drawn
  position and emitted the name it landed on. `ScatterPoint.x` is typed
  `number`, and the core does arithmetic on it: it sorts with
  `a.x - b.x`, indexes columns by the value, and resolves the nearest
  point with `Math.hypot`. A string makes the subtraction `NaN`, and a
  comparator returning `NaN` leaves `Array.prototype.sort` with no
  ordering to apply – so the points stayed in input order rather than
  the x order every downstream index assumes, and the hover/highlight
  resolver had no nearest point to find. The faceted chart announced the
  right *name* while handing the core a payload it could not sort, index
  or highlight against. The relabelling is removed rather than converted
  back: `xLabel` carries the name alongside the position, so the name
  never had to displace it. A faceted bar is unchanged – its `x` is
  legitimately a category, and a bar chart is navigated by name rather
  than by distance.

- ggplot2: one
  [`geom_hline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html)
  turned a fully supported chart into a static image. A reference line
  had no layer type, so it was classified `unknown` – and one unknown
  layer drops the *whole plot* to a base64 image. Measured with
  [`save_html()`](https://r.maidr.ai/reference/save_html.md):
  [`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)
  alone rendered a 44,353-byte interactive SVG, and adding a threshold
  line to it rendered a 14,680-byte image. The chart itself was fully
  supported; what it lost – sonification, braille, keyboard navigation,
  the text description – it lost to a target, a control limit, a prior
  year’s median. A reference line carries no observations, so it is now
  skipped, the mechanism that already keeps
  [`geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
  from forcing a fallback. Reading it instead would be worse than
  dropping it: a blended transform puts its coordinates in axes-fraction
  space, so it announces endpoints of 0 and 1 – a confident reading of a
  series that is not there.
  [`geom_vline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html)
  and
  [`geom_abline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html)
  are covered too. A plot made only of such layers still falls back,
  since there is nothing left to announce; that case was already live
  for `annotate("text")` alone, which claimed to be interactive while
  emitting no layers at all.

- ggplot2: a scatter with a missing value highlighted the wrong point.
  ggplot2 discards a sample whose position or value is missing before it
  renders – and says so, with “Removed 1 rows containing missing values”
  – but the point processor kept it, so `data` came out longer than the
  marks the selector resolves to. Measured on four rows with one NA:
  four points emitted against three drawn elements, which pairs every
  sample from the gap onward with the *next* observation’s mark and
  leaves the last with none. That is worse than an absent point, since a
  reader is shown a mark that does not correspond to the value being
  announced and nothing says so. Only the samples ggplot2 drew are
  emitted now, which is the rule the line processor already followed for
  the same reason. A missing `x` counts as well as a missing `y`, and
  the row indices the colour and group lookups read through are narrowed
  in step, so a mapped aesthetic still names the series a surviving
  point belongs to.

- ggplot2: a horizontal bar chart lost every label and every value.
  `ggplot(df, aes(y = g, x = n)) + geom_col()` is the ordinary spelling,
  and
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  marks such a layer `flipped_aes` and swaps which computed column holds
  what. The bar processor read `x` as the category and `y` as the
  measure unconditionally, so it picked up exactly the wrong pair: a
  chart of `apple = 30`, `banana = 70`, `cherry = 50` was announced as
  category `"30"` with value `1`, `"50"` with value `3` and `"70"` with
  value `2`. Three things at once – the fruit names appeared nowhere in
  the layer, the values were factor codes rather than counts, and the
  rows came out sorted by the measure rather than in the chart’s own
  order, so even the sequence a reader navigates did not match the bars.
  The `axes` block was right throughout, which made it worse: the axis
  names said which way round the chart was and the data underneath
  contradicted them. The columns, the mapping the category’s name is
  recovered from, and the panel scale its labels come from are now all
  exchanged for a flipped layer, and the layer carries an `orientation`
  key.
  [`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
  is deliberately still vertical: it rotates the coordinate system and
  leaves `flipped_aes` alone, so its columns are already the right way
  round.

- ggplot2: a horizontal histogram was announced with its bins and its
  counts swapped.
  [`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html)
  drawn with `aes(y = )` emitted correct data –
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  puts a flipped layer’s bin bounds in `ymin`/`ymax` and its count in
  `x`, and the processor passed both through as they came – but no
  `orientation` key saying which axis was which. The frontend defaults
  to vertical without one, so it read the bin range from `xMin`/`xMax`,
  where a flipped layer keeps the count bounds. A 60-point sample
  running -2.42 to -1.10 was announced with a bin range of “0 to 5”, and
  every bin centre was offered as a value in place of its count. Every
  number in the announcement was real and every one was on the wrong
  axis, with nothing erroring to say so. Read from `flipped_aes` now,
  the way the box plot and violin processors already do.
  [`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
  is deliberately still reported as vertical: it rotates the coordinate
  system and leaves `flipped_aes` alone, so the data layout the key
  describes is genuinely unflipped, and calling it horizontal would swap
  a pair that is already the right way round.

- ggplot2: a transformed scale was announced in transformed space.
  ggplot2 applies the transformation *before* the stat runs, so
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)’s
  data is in that space – and a
  [`scale_x_log10()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)
  scatter of prices from \$5.50 to \$9,403 read as 0.744 to 3.973 under
  the label “Price (USD)”. Nothing was missing, nothing errored, the
  structure, the point count and the label were all right, and the
  numbers were false, with no signal a reader could catch: “these look
  small” is not checkable without the chart you cannot see. Point,
  smooth and line layers now announce the values the axis shows.
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  was half-right beforehand, its x already recovered by its own path and
  its y not, which is the shape that made this easy to miss. A
  transformed axis emits no navigation grid: grid navigation walks equal
  increments, and 10, 100 and 1000 are equally spaced only in the space
  the points are no longer announced in, so a grid there would disagree
  with the announcement rather than merely be wrong alongside it. The
  axis keeps its label.
  [`coord_trans()`](https://ggplot2.tidyverse.org/reference/coord_transform.html)
  is deliberately untouched – it transforms at draw time, after the
  stat, so its data is already in data space and its scale reports
  `identity`, and the comparison that skips an untransformed chart skips
  it too.

- ggplot2:
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  and the error bar geoms emitted no data at all. Two helpers shared by
  every layer processor read the layer’s position from
  `layer_info$layer_index`, while all six places that build a
  `layer_info` name that field `index` – so both resolved to nothing for
  every processor the orchestrator creates, and the layers they serve
  rendered with an empty `data` array. Not a wrong reading: no reading,
  and no error anywhere on the path. Both now read through
  `get_layer_index()`, which was already the accessor for that field.
  The unit tests did not catch it because each builds its own
  `layer_info` and supplied the key the helpers expected, so the lookup
  succeeded in the tests and failed in the product; the regression test
  renders a chart through the real pipeline instead.

- ggplot2: an unsorted
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  announces each point’s own x. The built data is sorted by
  `(PANEL, group, x)` – that sort is the documented difference between
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  and
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  – while the caller’s column keeps its own order, and x was recovered
  by pairing the two row by row. Every point therefore carried another
  point’s coordinate: a series drawn 1, 2, 3 was announced 3, 1, 2, and
  nothing in the payload signalled it. x is now recovered from the built
  value itself – the panel’s own labels for a discrete scale, the
  scale’s inverse transformation for a Date or POSIXct, and the value
  as-is for a plain number – so it cannot desynchronise. Single and
  multi-series plots were both affected;
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html),
  which does not reorder, and faceted plots, which already recovered x
  by value, were not.

- ggplot2: a
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  or
  [`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  whose y aesthetic is a factor now carries the level *name* in its
  payload, as `label` on each point, the same pairing
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  already used.
  [`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
  replaces the level with its numeric position and the name survives
  only in the original column, so nothing downstream could recover it
  before. `y` stays numeric – it drives sonification, braille and the
  min/max range. A continuous y is untouched.

  This does not change what a reader hears yet. maidr’s JS line trace
  ignores a per-point `label`; only its step trace reads one, so a
  factor-y line chart still announces the level code. The announcement
  needs upstream support (xability/maidr#785); this is the half r-maidr
  owns.

- Fixed polyline selector assignment for plots that mix
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  and
  [`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html):
  the layer position was counted over line layers only while every
  polyline in the panel was searched, so both layers resolved to the
  same polyline and highlighted the wrong geometry.

- Base R charts drawn without `xlab=` / `ylab=` now announce axis titles
  that say what the numbers mean.
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) derive
  their titles inside the call rather than recording them, so the
  payload carried `label: ""` and every point was announced with its
  nouns missing: ” is Apples, is 30”. Each processor now emits what its
  call actually establishes — a pie’s categories against their values, a
  bar chart’s categories against their heights (swapped by
  `horiz = TRUE`), a histogram’s bins against the “Frequency” or
  “Density” [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  itself would print, `boxplot(y ~ g)`’s own formula-derived titles, and
  the columns and rows
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws.
  An author’s own label always wins. Where a chart can honestly say
  nothing — a scatter or line plot runs over whatever the caller
  measured, and the recorded arguments no longer name it — the label is
  omitted rather than blanked, so the renderer applies its generic
  “X”/“Y”.

- Base R: the function maidr replays a recorded call through is now
  always the one the owning namespace holds, never maidr’s own recording
  wrapper.
  [`find_original_function()`](https://r.maidr.ai/reference/find_original_function.md)
  probed `graphics`, `stats` and `grDevices` with R’s default inherited
  lookup, and a namespace environment’s parent chain ends at the *search
  path* — so any name those namespaces do not own was resolved against
  whatever happened to be attached, `package:maidr` included.
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md) hit
  this: maidr’s quantmod hook runs while quantmod is loaded but not yet
  attached, so maidr sat ahead of it on the path and maidr’s own stub
  was recorded as quantmod’s original. The replay then called that stub,
  which forwarded through `...` — the corruption described in the
  previous entry — failed, and only survived because of the retry added
  for it. The probes are now scoped to the namespaces they name, with
  `base` added to the chain because
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) lives
  there rather than in `graphics`. The exported payload is
  byte-identical either way; what changes is that the replay no longer
  takes a detour through maidr.

- Documentation: the internal R6 class reference pages no longer carry
  keyword entries made of ordinary English words. An R6 method docblock
  that opens with untagged title text instead of `@description` makes
  roxygen2 scatter that sentence’s individual words into the *class*
  block as `\keyword{}` entries, which `R CMD check` NOTEs as
  non-standard — `BaseRAdapter.Rd` had accumulated `\keyword{Check}`,
  `\keyword{a}`, `\keyword{the}` and the rest of “Check if this adapter
  can handle a plot object”. It also glued each such title onto the
  *previous* method’s Returns section. Both are fixed for the fifteen
  pages [\#104](https://github.com/xability/r-maidr/issues/104) left,
  along with a related cause: five module files opened a file-level
  block that was never terminated, so its text was absorbed into the
  first function documented below it. No user-visible behaviour changes.

- Base R: an argument passed by position now reaches the description
  under the name R matched it to. The patched functions are declared
  `function(...)`, so the recorded call kept only the names the caller
  typed: `hist(x, 20)` announced 9 Sturges bins over a picture of 22
  bars, silently, while `hist(x, breaks = 20)` was correct. Every
  recorded call is now matched against the definition R dispatched to —
  [`hist.default()`](https://rdrr.io/r/graphics/hist.html) for
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md), where
  `breaks` lives — before the processors read it, so `breaks`, `freq`,
  `names.arg` and their neighbours are honoured whichever way they were
  written. The argument R dispatches on is deliberately left exactly as
  the caller wrote it, so `plot(y ~ x, data = d)` still reaches
  `plot.formula()` when the figure is redrawn. A positional `type`
  reaches the description for the first time as part of this:
  `plot(x, y, "l")` was read as the default points and carried a
  selector that matched nothing, and is now the line it draws.
  `plot(x, y, type = "b")` is read as points rather than as a line, in
  both spellings — R draws `"b"` with a gap at every symbol, which
  gridSVG exports under a name the line selector cannot address, so that
  layer used to come out with no selector and no highlight at all; the
  symbols it also draws are addressable.

- Base R: [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of
  a matrix, data frame or time series announces the axis grid it draws.
  The axis code reimplemented the single-argument fallback by hand and
  flattened the input, so `plot(cbind(1:5, c(100, 200, 300, 400, 500)))`
  read all ten cells as y values and indexed x over 1:10: grid
  navigation ran to 10 on an axis drawn 1 to 5, reporting every point at
  roughly half its true horizontal position. The data itself was already
  right. Coordinates now come from
  [`grDevices::xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html),
  the same resolution the data extraction trusts, so matrices, data
  frames, `ts` objects and list inputs all announce the grid R drew — a
  `ts` starting in 2001 is announced 2001-2005 rather than 1-5, and
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of a data
  frame gains the grid it previously omitted.

- Base R: a
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) given
  its own `labRow=` / `labCol=` announces those labels.
  [`stats::heatmap()`](https://rdrr.io/r/stats/heatmap.html) resolves
  each axis as `labRow[rowInd] %||% rownames(x) %||% (1L:nr)[rowInd]`,
  so the caller’s labels come first and beat the matrix’s dimnames, and
  they are subscripted by the same clustering order as the data. maidr
  implemented only the second and third arms, so
  `heatmap(m, labRow = c("alpha", "beta", ...))` drew those words on the
  axis and announced the bare indices `2 5 4 3 1` beside them; a matrix
  that also carried dimnames announced the dimnames while the axis
  showed the caller’s strings. Both axes now take the supplied labels
  first, reordered the way the drawing is. A call that passes no labels
  is unchanged, as is
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md), which
  has no such argument.

- ggplot2: the panel a facet draws for a missing value is no longer
  announced as empty in dodged bar and heatmap plots. Both picked their
  panel’s rows with `==`, which answers `NA` for exactly the rows whose
  facet value is missing, and `[` turns an `NA` index into a fabricated
  all-`NA` row. The dodged layer was dropped from that panel’s payload
  altogether, so arrowing into it announced nothing at all; the heatmap
  layer survived with its row and column labels but scored no cells, so
  it read as an empty grid. ggplot2 draws real bars and tiles there and
  writes “NA” on the strip, so in both cases the reader was told the
  panel was empty while a sighted reader could see it was not. Both now
  use the same `NA`-safe row test the stacked processor was given, and
  the panel is announced as “NA” — the two characters ggplot2 prints on
  its strip — with a facet level literally spelled `"NA"` still kept
  distinct from it. A dodged `stat = "count"` panel keeps its
  rectangular cross-tabulation, so an absent combination in the restored
  panel still reports a genuine `0`.

- ggplot2: a
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  whose data is not a complete grid highlights the bar it is announcing.
  Pre-aggregated tidy data routinely omits a combination — the reason
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  exists — and both the dodged and the stacked processor emitted one
  entry per supplied row, so the series came out ragged (3 and 2 for a
  three-category, two-group frame). The frontend regroups one flat list
  of rectangles across a grid it sizes from the first series, so a
  ragged payload cross-mapped the announcement onto a bar in a different
  category *and* a different fill group, and left the last bar of the
  longest series with no highlight at all. A stacked chart lost a whole
  column on top of that, and dropped an entire fill level when the first
  category was the one missing it — that group could then not be reached
  at all. Both processors now emit the full grid, and the stacking order
  is read from the fullest column rather than the first. Cells the
  caller never supplied carry `NA` rather than `0`: the frontend needs
  them to occupy a slot, but it reads them through its missing-value
  path, so a screen reader hears “n is missing” — not a zero the data
  never claimed. Each facet panel completes its own frame, which also
  settles a panel whose rows happen to be incomplete on their own.
  `stat = "count"` is unchanged and still reports a genuine `0` for a
  cross-tabulation cell that counted nothing, and a frame carrying a
  real `NA` in its `x` or `fill` column keeps its previous reading
  rather than losing that row to a grid with no column to hold it.

- Base R:
  [`library(maidr); library(quantmod); chartSeries(SPY)`](https://github.com/xability/r-maidr)
  no longer fails silently and then blames the user. Attaching
  ‘quantmod’ puts `package:quantmod` ahead of `package:maidr` on the
  search path, so a bare
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  binds to quantmod’s own function and maidr’s recording wrapper is
  never entered: the chart drew as a plain inaccessible graphic and
  [`show()`](https://r.maidr.ai/reference/show.md) /
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) then
  stopped with “No Base R plots detected. Please create a plot first”,
  which is false — a chart *was* drawn. An earlier NEWS entry claimed
  this case was already handled; it never was, and that claim has been
  corrected. maidr does not overwrite quantmod’s bindings to win the
  search-path race, because that would also route quantmod’s own
  internal
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  calls through maidr’s wrapper. Instead the ordering problem is now
  reported: attaching ‘quantmod’ after ‘maidr’ prints a startup message
  naming the masking, and the “No Base R plots detected” error names it
  too, in both cases pointing at the two working options — attach
  ‘quantmod’ before ‘maidr’, or call
  [`maidr::chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  explicitly. Attaching ‘quantmod’ first, and
  [`maidr::chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  record and export as before.

- Base R: `maidr::chartSeries(x, type = "candlesticks", TA = NULL)` no
  longer dies with “no applicable method for `@` applied to an object of
  class "name"” when ‘quantmod’ is loaded but not attached. quantmod
  records its own arguments with `match.call(expand.dots = TRUE)`;
  forwarded through maidr’s `...` that record holds the dot symbols
  rather than the caller’s expressions, so an explicit `TA = NULL`
  arrived as a symbol and quantmod tried to take an S4 slot from it. The
  call is now retried with the arguments rebuilt in the caller’s frame —
  the same fallback maidr’s generated wrappers already used, which is
  why attaching ‘quantmod’ first was unaffected.

- Base R: a
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) grid in
  which one panel spans several cells no longer advertises the rest of
  the span as empty subplots.
  `layout(matrix(c(1, 1, 1, 2, 3, 4), 2, 3, byrow = TRUE))` draws panel
  1 across the whole top row, but the two cells it covered were emitted
  with no layers, no title and no selector, so a four-panel figure
  announced six subplots and arrowing into either cell threw in the
  browser instead of announcing anything. Every cell a panel spans now
  carries that panel, so navigation across the span keeps announcing and
  highlighting it; the panel is still one plot, reported once per cell
  it covers. A `0` in the layout matrix, and a panel the matrix declares
  but the user never drew, still emit an empty cell — those are
  genuinely blank. `par(mfrow)` and `par(mfcol)` grids cannot span and
  are unchanged.

- Base R: [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  of a matrix with no `dimnames` announces the row and column identities
  it actually draws.
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  clusters the rows and columns and then labels the reordered matrix
  with the *original* indices, `(1L:nr)[rowInd]`; maidr instead filled
  unnamed axes with a plain 1..n position sequence, so a default
  `heatmap(m)` announced “row 5” while sonifying the values of original
  row 2. Only the labels were affected — the values have been drawn from
  the same ordering since dendrogram support landed, which left the
  payload internally inconsistent as well as wrong against the figure.
  Unnamed axes now take their labels from that ordering, on both the row
  and the column axis, and `revC` (which every `symm = TRUE` call turns
  on) reverses labels and values together as before. Matrices that carry
  `dimnames` are unchanged, as are `Rowv = NA, Colv = NA` heatmaps and
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md), none of
  which reorder anything, so 1..n is what they draw.

- ggplot2: a grouped
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  keeps its highlight when another layer in the same panel also draws
  polylines. A grouped line draws all of its curves as one grob that
  gridSVG splits per curve, while a sibling
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  contributes grobs of its own; the layer’s selector was picked by
  indexing that flat panel-wide list of grobs by the layer’s position
  among line layers, so `geom_line(aes(colour = g)) + geom_smooth()`
  emitted three series and one selector. The frontend requires one
  selector per series and drops the whole layer’s highlight otherwise,
  so nothing on screen moved as the reader walked any of the three
  lines. The layer’s own grob is now resolved first and its curves
  enumerated from it, giving one selector per series; two line layers in
  one panel likewise each resolve to their own grob. When the curves
  cannot be lined up with the series, no selector is emitted rather than
  one of the wrong length.

- ggplot2: a faceted stacked bar whose facet column contains `NA`
  exports again. ggplot2 draws a real extra panel for the missing value,
  but the per-panel subset picked its rows with `==`, which answers `NA`
  for exactly those rows, and `[` turns an `NA` index into a fabricated
  all-`NA` row — so one missing facet value contaminated every panel,
  not only its own.
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) aborted
  with `argument 1 is not a vector` and wrote no file at all;
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  and `stat = "identity"` were affected, `stat = "count"` was not. Each
  panel now reads only its own rows, the missing-value panel reads the
  rows whose facet value is `NA`, and it is announced as “NA” — the same
  two characters ggplot2 prints on its strip. Two neighbouring
  assumptions in the same layer go with it: the values are no longer
  paired with the drawn rectangles row by row once the two frames differ
  in length (a layer carrying its own `data =` argument used to announce
  categories it never drew), and a row ggplot2 could not position, such
  as one with a missing `y`, no longer counts as part of the layer.

- ggplot2: a faceted line plot on a transformed x scale announces the
  data values again instead of the transformed positions behind them.
  Under
  [`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
  plus
  [`scale_x_log10()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html),
  points labelled 1, 10, 100 and 1000 on the axis were read out as 0, 1,
  2 and 3;
  [`scale_x_reverse()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)
  negated every value and
  [`scale_x_sqrt()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)
  reported square roots. Panels now put the data through the same
  transformation the scale applied before matching, so what is announced
  matches the drawn axis. Faceted panels also read break labels off
  their own scale rather than the first panel’s, which matters under
  `scales = "free_x"`. Untransformed, date and date-time faceted panels
  are unchanged, as are all unfaceted line plots.

- ggplot2: a facet level that drew nothing no longer breaks the chart’s
  highlighting. A layer with no highlight target was emitting an empty
  selector list, and the frontend passes that value straight to
  `document.querySelectorAll()`, where an empty selector raises a
  `SyntaxError` inside the trace it was building. On a histogram,
  stacked bar or dodged bar under `facet_wrap(~g, drop = FALSE)` with an
  unused level, keyboard navigation then produced no highlight anywhere
  in the figure, while the chart still looked correct. Such a layer now
  omits the field instead, which is the value the frontend reads as
  “nothing to highlight”.

- ggplot2: an empty facet panel no longer emits a layer describing
  nothing. A processor that drew nothing in a panel returns no data, and
  that was being wrapped into a single empty series, so a reader
  entering the panel was told it held a plot and then heard its fields
  announced as undefined, with the sonification failing on a non-finite
  value. The panel now carries no layers, the same shape a Base R
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) cell
  with no plot already has.

- ggplot2: a grouped smooth is described as one series per curve.
  `geom_smooth(aes(colour = g))` draws a curve per group, but the
  payload concatenated all of them into a single undifferentiated series
  with no `z`, so a reader walked off the end of one curve into the
  start of the next with nothing announced in between. The layer also
  carried a single selector aimed at one group’s polyline, leaving three
  times as many data points as the highlighted line had vertices. Each
  group is now its own series, named after the group and labelled with
  the legend title, with its own selector.
  [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
  splits the same way, including when the grouping is mapped to `fill`.

- LaTeX in MAIDR’s AI chat responses renders styled again. MAIDR 3.75.1
  split KaTeX out of `maidr.css` — which became a placeholder with no
  rules in it — into `maidr-math.css`, which `maidr.js` fetches at
  runtime from whichever directory it was itself loaded from. The
  bundled assets tracked that release without picking up the new file,
  so `maidr.css` was still linked (styling nothing) and the stylesheet
  that does style mathematics was absent. The bundle now ships
  `maidr-math.css` beside `maidr.js`, and no stylesheet is linked: MAIDR
  styles its interface at runtime and fetches that one file for itself.
  Its embedded KaTeX web fonts are still stripped to keep the installed
  package under CRAN’s size limit, so glyphs fall back to system fonts
  while the layout rules — spacing, fractions, radicals, delimiters —
  are intact.

- ggplot2: histogram, stacked bar, dodged bar, and smooth layers no
  longer invent a highlight target when the grob lookup finds nothing. A
  facet level with no observations (`facet_wrap(~g, drop = FALSE)`), a
  zero-row layer, and a segmented bar under
  [`coord_polar()`](https://ggplot2.tidyverse.org/reference/coord_radial.html)
  all draw no marks, and these four layers answered with a guessed
  element id instead of no selector at all. The guess never matched for
  the three rect layers, so the payload looked healthy while the layer
  highlighted nothing; for smooth it was worse, since the guessed id was
  byte-identical to the first panel’s, and the empty panel highlighted
  another panel’s fitted line. They now emit no selector, matching bar,
  point, box plot, line, heat map, and candlestick layers.

- ggplot2: a dodged
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  no longer highlights the wrong bar when some (x, fill) combinations
  are empty. The layer emitted only the combinations it actually drew,
  so
  `ggplot(mpg, aes(class, fill = drv)) + geom_bar(position = "dodge")`
  produced series of five, four and three values against a chart of
  seven categories. MAIDR walks one flat list of rects column by column
  and sizes that walk from the payload, so a ragged payload claimed
  fifteen bars where twelve exist: the cursor overran and every bar
  after the first empty cell highlighted its neighbour, while position
  three meant `pickup` in one series and `minivan` in the next. Absent
  combinations are now announced as zero, which keeps each series one
  entry per category so the same position means the same category in all
  of them, and which is the honest value for a cross-tabulation – a cell
  `stat = "count"` never drew is a cell whose count really is zero, and
  MAIDR gives it no highlight because there is no bar to highlight. Bars
  supplied through
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  are left alone: a row the caller omitted has no value, and inventing a
  zero for it would invent data. Dodged counts also asked for the wrong
  per-column highlight direction, which put every series on its
  neighbour’s bars even when no combination was empty.

- ggplot2: a dodged
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  now announces its categories in the plotted order. The layer sorted
  them as text, which disagreed with the chart twice over: a factor is
  laid out in level order, so reversed or custom levels described column
  one of the payload against column three of the chart, and a number
  sorts with 10 before 2.

- ggplot2: a faceted panel no longer discards the display hints its
  layers emit. The panel entry was assembled from a fixed list of keys,
  so anything else a processor returned – `domMapping`, `orientation`,
  the box plot’s IQR direction – was dropped, and every panel fell back
  to defaults the unfaceted plot never uses. A faceted dodged
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  therefore highlighted its neighbour’s bars in every panel. The
  ‘patchwork’ path already carried these fields; the facet path now
  matches it.

- Base R: [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  renders as an interactive line plot instead of a static image. The
  call was recorded, but the adapter had no layer type for it, so it
  typed as “unknown” and the whole figure fell back to a picture with no
  sonification, braille, or keyboard navigation. It now types as the
  same line layer `plot(x, y, type = "l")` produces, and the announced
  points are the ones
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) returned
  after drawing them, so they cannot drift from what was plotted. The
  axis labels
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) derives
  for itself – the variable name and the deparsed expression – are
  announced too. Draw types that are not a polyline (`type = "p"`,
  `"b"`, `"s"`, …) and `curve(add = TRUE)` keep the static fallback.

- Base R: [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  called from inside a function sees that function’s variables.
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) resolves
  the free variables of its expression against the calling frame, which
  through maidr’s wrapper was the wrapper’s own frame, so
  `f <- function(k) curve(sin(k * x), from = 0, to = pi)` failed with
  “object ‘k’ not found” – a call that works in plain R. It only
  appeared to work at top level, where the global environment is on the
  package’s search chain.

- ggplot2: a ‘patchwork’ panel no longer loses the axis labels ggplot2
  computes. Each leaf’s layout was read before the leaf was built, and
  under ggplot2 v4 an unbuilt plot carries only the labels an explicit
  [`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) set, so
  a
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  inside a composition announced the placeholder “Y” in place of
  “count”. The leaf is now built first and its layout read from the
  result.

- ggplot2: faceted plots no longer lose their axis labels. Each panel
  rebuilt its own axes from the unbuilt plot, which under ggplot2 v4
  records only the labels an explicit
  [`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) set –
  everything ggplot2 derives while building was dropped. Every faceted
  panel therefore announced the placeholder “Categories” for x and
  nothing at all for y, so a faceted
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  said “Categories is suv” where the unfaceted one says “class is suv,
  count is 62”. Panels now keep the labels their layers resolved,
  including the legend title. A panel collapses all of its layers into
  one description, so the labels are assembled across them: a plot whose
  first layer is ungrouped and whose second is grouped –
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  under `geom_line(aes(colour = g))`, say – still wrote the group into
  the data while carrying no title for it, and MAIDR announced the
  generic word “Group”.

- ggplot2: a multi-series line plot now announces its legend title
  instead of the word “Group”. The layer already emitted a per-series
  group name, which MAIDR reads out as “ is ”, but the payload carried
  no label for it, so the viewer fell back to a generic placeholder and
  the title set by `labs(colour = ...)` – or the mapped column name when
  no title was set – was never spoken, brailled, or shown in the chart
  description. Stacked bar, dodged bar, and heatmap layers already
  carried theirs; line layers now do too.

- patchwork: layer ids are unique across a whole composition. Every leaf
  numbered its layers from 1, so a 2x2 patchwork emitted four layers all
  called `maidr-layer-1`. The frontend keys its per-figure number-format
  map on the bare layer id, so the last leaf’s formats overwrote every
  other leaf’s and the wrong ones were announced; a
  candlestick-over-volume composition was worse, because collapsing its
  two panels into one subplot put two identically named layers side by
  side. Ids now carry the panel’s grid cell.

- ggplot2: axis number formats are honoured inside a ‘patchwork’. A
  `scale_y_continuous(labels = ...)` wrapper was applied on a single
  plot and on a faceted plot, and silently ignored the moment the same
  plot went into a composition, so values were announced unformatted –
  currency read as a bare number, percentages without their sign. The
  patchwork path never extracted a format config or ran the
  [`validate_axes()`](https://r.maidr.ai/reference/validate_axes.md)
  contract check the other two paths run; it now does both, per leaf, so
  each plot in a composition keeps its own formats.

- Base R: one annotation overlay no longer silences a whole multi-panel
  figure. A
  [`segments()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`arrows()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`rect()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
  [`polygon()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
  can carry data maidr cannot read, so the panel holding it is still
  declined rather than described incompletely – but the decline used to
  take the entire figure with it. A single arrow pointing at an outlier
  in one cell of a `par(mfrow = c(2, 2))` grid cost the other three
  panels their sonification, braille and keyboard navigation, and left
  the reader with a static image. Only the annotated panel now goes
  quiet; it is still drawn, the rest of the grid stays interactive, and
  the warning names the panel that fell back. Single-panel figures,
  figures whose every panel is annotated, overlays drawn outside the
  exported grid, and grids holding a plot type maidr cannot read at all
  still fall back as a whole, as before.

- Base R: highlighting in a multi-panel figure now follows the panel
  actually drawn. Only the panel-visible plot groups are replayed, so
  the exported SVG numbers its panels in replay order, but each panel
  looked its elements up by the plot group’s own index. One skipped
  group – a plot drawn before the `par(mfrow = ...)` call, or a page
  that scrolled off when more plots were drawn than the grid holds –
  shifted every later panel, so panel 1 lit up panel 2’s bars and the
  last panel highlighted nothing at all. This affected `mfrow`, `mfcol`
  and [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  grids alike.

- Base R: a
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) drawn
  with `revC` – which every `symm = TRUE` call turns on, since `Colv`
  defaults to `"Rowv"` there – is no longer described upside down.
  `revC` flips the drawing so the first reordered row lands at the top,
  but it is not part of the ordering
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  reports, so the emitted grid was reversed anyway: two calls differing
  only in `revC` produced byte-identical data for mirror-image figures,
  and every row label named the row on the opposite side of the plot.

- ggplot2: a faceted bar chart on a continuous, `Date` or `POSIXct` x
  axis no longer announces the wrong x value. Each panel labelled its
  bars by using the bar’s x position as an INDEX into that panel’s axis
  break labels, which is only meaningful for a discrete axis where those
  positions are category numbers. On a numeric axis the positions are
  the values themselves, so `c(2, 4, 6)` was announced as “2”, “6”, “6”,
  `c(1, 2, 3)` lost its first label entirely, and a `Date` axis
  announced raw day counts (“19723”) rather than dates. Non-discrete
  panels now report their own values, formatted the same way an
  unfaceted chart formats them.

- ggplot2: bar, point, line, box, histogram, smooth, stacked-bar,
  dodged-bar, heatmap and candlestick plots inside a NESTED ‘patchwork’
  are no longer inert. Each of these carried its own panel lookup that
  scanned only the top level of the composition and addressed panels by
  name, but `(p1 | p2) / p3` keeps the inner row’s panels inside a child
  table and leaves only a placeholder at the top, and panel names repeat
  across nesting levels anyway. A nested leaf therefore failed in one of
  two ways: bar, point, box, line, heatmap and candlestick emitted no
  selector at all, while histogram, smooth, stacked bar and dodged bar
  fell through to a fabricated selector that matched nothing – the worse
  of the two, because the payload looks healthy while the layer
  highlights nothing. Every processor now resolves its panel through the
  same recursive walk the violin processor already used, and each leaf
  addresses its own panel. Flat compositions and faceted plots are
  unaffected.

- The startup message no longer promises something the package does not
  do. It told every user, on every
  [`library(maidr)`](https://github.com/xability/r-maidr), that plots
  are displayed in the interactive viewer by default. That is true for
  ggplot2, which hooks `print.ggplot`, and has never been true for Base
  R: those plots are recorded to a hidden device and wait for an
  explicit [`show()`](https://r.maidr.ai/reference/show.md). The message
  now says which is which.

- Asset loading: the internet probe is no longer cached for the whole
  session. It was probed once and never re-checked, so the first answer
  decided CDN-versus-inline for the life of the process – a transient
  failure inlined the bundle into every later document, and a machine
  that went offline after a successful probe kept emitting CDN
  references, leaving plots dead in the browser exactly when the user
  could not debug them. The result now expires after five minutes, which
  still costs one probe per render rather than one per plot.

- knitr: turning interception off mid-document no longer leaves recorded
  Base R calls behind. The hook returned early when interception was
  disabled without clearing the device, unlike the sibling branch for
  non-HTML output, so a document that plotted, called
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md), then
  called [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) again
  folded the earlier calls into the next render as phantom layers.

- Base R: a plot drawn in a loop now renders the iteration it recorded.
  When an argument cannot be evaluated where the call is intercepted –
  the shape `plot(y ~ x, data = d, subset = grp == g)`, which mixes a
  column of `data` with a variable from the loop – maidr records the
  unevaluated expressions and re-evaluates them at render time. It
  recorded the caller’s frame to re-evaluate them in, and R reuses ONE
  frame for the whole loop, so by render time every iteration saw the
  LAST iteration’s values:
  `for (g in c("a", "b")) plot(y ~ x, data = d, subset = grp == g)` drew
  `grp == "b"` in both panels, with no error and no warning. The values
  the recorded expressions name are now captured when the call is made,
  so each panel replays its own data. Only the names actually referenced
  are captured, into a child of the caller’s frame, so everything else
  still resolves as before and active bindings are left to the caller.
  Applies to every deferred path:
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`points()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md).

- ggplot2: a violin plot combined with ‘patchwork’ is no longer silent.
  The leaf emitted a subplot with no layers at all – no sonification, no
  braille, no highlighting for that panel – because the processor
  skipped every call that carried a panel context, a guard meant only
  for faceted violins. Patchwork leaves now emit the same `violin_box`
  and `violin_kde` layers a standalone violin does, with selectors
  scoped to their own panel and KDE highlight coordinates read from
  their own panel’s viewport, including for violins nested inside a
  patchwork row. Faceted violins remain unsupported.

- ggplot2: a patchwork containing a faceted plot now pairs each of its
  other plots with the right panel. A faceted plot draws one panel per
  facet cell while still counting as one plot, so every plot after it
  was described over someone else’s panel, and the surplus panels
  repeated the last-added plot’s data – the same numbers announced in
  three places, only one of them reachable. Panels are now consumed per
  plot, so each is announced once, on its own panel.

- ggplot2: the box statistics of a violin plot now describe the group
  they are announced with. The quartiles were recomputed from the drawn
  geometry rather than read from ggplot2’s own `stat_boxplot` output, so
  a violin split by `fill` announced one set of class-wide numbers over
  every one of its dodged violins – `aes(class, hwy, fill = drv)`
  emitted 7 labels for 12 violins, each repeated. A
  [`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
  violin read its labels off the vertical axis, which is now the
  continuous one, and reported every quartile as 0. A violin on a
  continuous axis matched labels by position index, announcing a `7` for
  `cyl` that no car has. All three now report each group’s own quartiles
  under its own label, dodged violins included.

- ggplot2: `geom_violin(width = 0)` no longer errors out of rendering
  with “missing value where TRUE/FALSE needed”. A violin drawn with no
  width has nothing to scale the density against; it now renders, and
  any positive widths in the same layer still scale normally.

- ggplot2: a plot placed after an
  [`inset_element()`](https://patchwork.data-imaginist.com/reference/inset_element.html),
  [`free()`](https://patchwork.data-imaginist.com/reference/free.html)
  or
  [`wrap_elements()`](https://patchwork.data-imaginist.com/reference/wrap_elements.html)
  in a patchwork is described again. Those wrappers put a plot in a cell
  panel discovery does not recognise, so it contributes no panel – but
  it was still counted as occupying one, which pushed every later plot
  onto somebody else’s panel and the last of them off the end.
  `patchwork::free(p1) | p2` announced nothing for `p2` at all.

- ggplot2: one plot a processor cannot handle no longer aborts the whole
  patchwork. Rendering failed for the entire composition; now that panel
  is silent and the rest of the figure is still described.

- Shiny:
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md)
  renders Base R plots again. It branched on the expression’s return
  value, which says nothing about whether anything was drawn –
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) returns
  NULL invisibly, so it was treated as an empty reactive and rendered a
  silent blank, while
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) return a
  non-plot value and errored the output slot with “Input must be a
  ggplot object”. Only ggplot worked.
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) now
  asks whether the expression actually recorded any drawing, so all
  three render. An expression that draws nothing and returns NULL still
  renders nothing.

- Base R: recorded plot calls now capture non-standard-evaluation
  arguments safely, so `curve(sin(x))` no longer errors or records stale
  values; replay evaluates them in the original environment.

- Base R: a multi-panel grid is no longer destroyed by the idiomatic
  trailing `par(mfrow = c(1, 1))` reset. A layout call issued after the
  last plot governs nothing that was drawn, so it no longer wins over
  the layout the panels were actually drawn under.

- Base R: `hist(x, plot = FALSE)` / `boxplot(x, plot = FALSE)` are no
  longer recorded as plot calls (previously they injected phantom layers
  into the next render).

- Base R: extracted bar data now always matches the rendered SVG order.
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) no
  longer re-sorts labels alphabetically out of sync with the drawn bars,
  unnamed vectors keep call order, and the sorted arguments the wrapper
  draws are also what gets recorded and replayed.

- Base R: matrix
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) without
  an explicit `beside` argument is now correctly detected as stacked
  (barplot’s default), not simple bars.

- Base R: `legend.text` no longer contaminates stacked/dodged bar
  highlight selectors with the legend’s swatch rectangles.

- Base R: `barplot(horiz = TRUE)` now emits `orientation = "horz"` with
  value/label roles swapped so announcements and navigation are correct.

- Base R: [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  now reproduces the dendrogram row/column reordering it draws with,
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md) no longer
  transposes rows and columns, both accept positional matrix arguments,
  and per-cell selectors fix the vertically mirrored cell highlighting.

- Base R: [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  recomputation now honours `right`, `include.lowest`, and `nclass`, and
  probability/density histograms announce densities instead of counts.

- Base R: `plot(v, type = "l")`, `lines(v)`, and `plot(v)` single-vector
  calls no longer crash or emit NA values; graphical parameters can no
  longer be mistaken for data arguments.

- Base R: box plot outlier highlights now follow the actual drawing
  order instead of assuming lower outliers are drawn first.

- Base R: multiline selectors are ordered numerically, so plots with ten
  or more series map each series to the correct polyline.

- Base R: multipanel handling fixes -
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md)-based
  grids are treated as multipanel, plots beyond the grid follow R’s
  new-page behaviour, plots drawn before the layout call are excluded,
  per-panel [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  format configs stay per-panel, empty grid cells serialize as valid
  subplots, and processor fields (orientation, domMapping) are
  preserved.

- Base R: fallback replay to the native device now replays
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md)/
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md) calls in
  original order and strips maidr-internal arguments.

- Base R: `title`/`subtitle` extraction no longer partial-matches
  unrelated arguments (e.g. `subset`) and tolerates non-character
  values.

- Base R: unsupported data-bearing overlays
  ([`polygon()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`rect()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`segments()`](https://r.maidr.ai/reference/base-r-wrappers.md), …)
  now trigger the documented fallback instead of being silently dropped
  from the accessible output.

- Base R: `plot(y ~ x, data = d, subset = ...)` and
  `boxplot(y ~ g, data = d, subset = ...)` work again. The formula
  methods resolve `subset` relative to
  [`parent.frame()`](https://rdrr.io/r/base/sys.parent.html), which the
  recording wrapper displaced, so these calls failed with “object ‘g’
  not found” and “..3 used in an incorrect context” even though they
  work in plain R.

- Base R: `matplot(m)` on a matrix again emits one series per column.
  Routing a lone matrix through
  [`xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html) read a
  two-column matrix as an x/y pair, so every series but one vanished
  from the accessible output and the first series’ values were announced
  as x coordinates.

- Base R: `barplot(x, plot = FALSE)` is no longer recorded as a plot
  call. The rule was applied to the generic wrapper only, and
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has its
  own code path.

- Base R:
  [`cancel_auto_show()`](https://r.maidr.ai/reference/cancel_auto_show.md)
  removes its task callback by name. It used the index
  [`addTaskCallback()`](https://rdrr.io/r/base/taskCallback.html)
  returned, which is a position in R’s callback list, so an unrelated
  package’s callback could be removed instead.

- Base R:
  [`maidr::chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  is recorded even when ‘quantmod’ is loaded after ‘maidr’. (Corrected
  in the development version: this entry originally claimed
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  calls were recorded whenever ‘quantmod’ was loaded after ‘maidr’,
  which was never true of
  [`library(quantmod)`](https://www.quantmod.com/). Attaching ‘quantmod’
  after ‘maidr’ masks maidr’s wrapper — see the development-version
  notes.)

- ggplot2: faceted box plots, histograms, smooths, heatmaps, and
  stacked/dodged bars no longer crash with “unused arguments”; extracted
  data and selectors are now scoped to each facet panel. Faceted violins
  stop crashing too, but they are skipped rather than made interactive:
  the facet combiner emits at most one layer per panel and so cannot
  carry a violin’s `violin_box` + `violin_kde` pair.

- ggplot2: dodged bars accept expression aesthetics such as
  `aes(fill = factor(cyl))`. Aesthetics were resolved with
  [`rlang::as_label()`](https://rlang.r-lib.org/reference/as_label.html)
  and used as column names, so `data[["factor(cyl)"]]` was `NULL` and
  the plot died with “all arguments must have the same length”.
  Aesthetics are now evaluated against the data, which also makes the
  row ordering match the drawn bars for expression aesthetics.

- ggplot2: each faceted box plot panel is announced with its own
  category names. Names were read from an unfiltered vector of axis
  positions indexed by position within the panel, so a panel drawing its
  boxes at positions 3 and 4 was labelled with the categories at
  positions 1 and 2 — correct quartiles under the wrong names.

- ggplot2: nested patchwork layouts (e.g. `(p1 | p2) / p3`) no longer
  drop panels from the accessible output.

- ggplot2: histogram and smooth layers extract their own layer’s data
  instead of the first similarly-shaped layer in multi-layer plots.

- ggplot2: scatter point colour/grouping values are emitted again,
  faceted plots included. The category lookup compared a panel-filtered
  row count against the whole data set; the two never matched under
  faceting, so every faceted scatter announced raw hex codes (`#F8766D`)
  instead of category names.

- ggplot2: each faceted heat map panel reports its own cell values.
  Cells were looked up in the unfiltered source data by (x, y) label,
  which matches a row in every panel, and the first match won — so all
  panels reported panel 1’s values.

- Base R: [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  matrices no longer count their empty `0` cells as panels when tracking
  device state, matching the panel grouping code.

- ggplot2: heatmap axis mappings follow factor level order instead of
  data-appearance order.

- ggplot2: [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md)
  now really disables RMarkdown interception, PDF and LaTeX output keep
  their figures, a second
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) no longer
  risks infinite hook recursion, and non-HTML output uses the original
  knitr plot hook instead of hardcoding the markdown hook.

- Shiny/widgets: `show(as_widget = TRUE)` and widget rendering now
  support Base R plots,
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md)
  renders nothing (instead of erroring) for NULL reactives, and device
  storage is cleared on the shiny/widget paths.

- Rendering: maidr-data JSON keeps full numeric precision (previously
  values were silently rounded to 4 decimal digits), `NA` handling is
  unchanged, and non-ASCII text in iframes is UTF-8 safe on all locales.

- Rendering: plot IDs no longer consume random numbers, preserving
  [`set.seed()`](https://rdrr.io/r/base/Random.html) reproducibility of
  user scripts.

- [`maidr_set_fallback()`](https://r.maidr.ai/reference/maidr_set_fallback.md)
  now keeps unspecified settings instead of silently resetting them to
  defaults.

- Scale label mapping keys labels by actual break positions, fixing
  mislabeled categories with custom break subsets.

### Enhancements

- CDN assets are pinned to the bundled MAIDR.js version instead of
  `@latest`, so the emitted schema and frontend can no longer drift
  apart.
- Iframe height auto-resize now also works in RMarkdown documents (the
  postMessage listener previously shipped only with the htmlwidgets
  binding).

### Performance

- ggplot2 plots are built once per render instead of three times; the
  faceted and patchwork paths reuse the built plot instead of rebuilding
  it per layer.
- Base R renders reuse the replayed gtable instead of re-replaying every
  recorded call on each access.
- Candlestick SVG post-processing parses the document once instead of
  five times.
- The multi-megabyte bundled JS/CSS assets are read once per session
  instead of once per rendered plot, and the offline-detection probe is
  cached per session instead of hitting the network for every plot.

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
