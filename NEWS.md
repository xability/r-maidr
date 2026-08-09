# maidr (development version)

## Bug Fixes

* ggplot2: a `geom_col()` whose data is not a complete grid highlights the bar
  it is announcing. Pre-aggregated tidy data routinely omits a combination —
  the reason `geom_col()` exists — and both the dodged and the stacked
  processor emitted one entry per supplied row, so the series came out ragged
  (3 and 2 for a three-category, two-group frame). The frontend regroups one
  flat list of rectangles across a grid it sizes from the first series, so a
  ragged payload cross-mapped the announcement onto a bar in a different
  category *and* a different fill group, and left the last bar of the longest
  series with no highlight at all. A stacked chart lost a whole column on top
  of that, and dropped an entire fill level when the first category was the
  one missing it — that group could then not be reached at all.
  Both processors now emit the full grid, and the stacking order is read from
  the fullest column rather than the first. Cells the caller never supplied
  carry `NA` rather than `0`: the frontend needs them to occupy a slot, but it
  reads them through its missing-value path, so a screen reader hears "n is
  missing" — not a zero the data never claimed. Each facet panel completes its
  own frame, which also settles a panel whose rows happen to be incomplete on
  their own. `stat = "count"` is unchanged and still reports a genuine `0` for
  a cross-tabulation cell that counted nothing, and a frame carrying a real
  `NA` in its `x` or `fill` column keeps its previous reading rather than
  losing that row to a grid with no column to hold it.
* Base R: `library(maidr); library(quantmod); chartSeries(SPY)` no longer
  fails silently and then blames the user. Attaching 'quantmod' puts
  `package:quantmod` ahead of `package:maidr` on the search path, so a bare
  `chartSeries()` binds to quantmod's own function and maidr's recording
  wrapper is never entered: the chart drew as a plain inaccessible graphic
  and `show()` / `save_html()` then stopped with "No Base R plots detected.
  Please create a plot first", which is false — a chart *was* drawn.
  An earlier NEWS entry claimed this case was already handled; it never was,
  and that claim has been corrected. maidr does not overwrite quantmod's
  bindings to win the search-path race, because that would also route
  quantmod's own internal `chartSeries()` calls through maidr's wrapper.
  Instead the ordering problem is now reported: attaching 'quantmod' after
  'maidr' prints a startup message naming the masking, and the "No Base R
  plots detected" error names it too, in both cases pointing at the two
  working options — attach 'quantmod' before 'maidr', or call
  `maidr::chartSeries()` explicitly. Attaching 'quantmod' first, and
  `maidr::chartSeries()`, record and export as before.
* Base R: `maidr::chartSeries(x, type = "candlesticks", TA = NULL)` no longer
  dies with "no applicable method for `@` applied to an object of class
  \"name\"" when 'quantmod' is loaded but not attached. quantmod records its
  own arguments with `match.call(expand.dots = TRUE)`; forwarded through
  maidr's `...` that record holds the dot symbols rather than the caller's
  expressions, so an explicit `TA = NULL` arrived as a symbol and quantmod
  tried to take an S4 slot from it. The call is now retried with the
  arguments rebuilt in the caller's frame — the same fallback maidr's
  generated wrappers already used, which is why attaching 'quantmod' first
  was unaffected.
* Base R: a `layout()` grid in which one panel spans several cells no longer
  advertises the rest of the span as empty subplots. `layout(matrix(c(1, 1, 1,
  2, 3, 4), 2, 3, byrow = TRUE))` draws panel 1 across the whole top row, but
  the two cells it covered were emitted with no layers, no title and no
  selector, so a four-panel figure announced six subplots and arrowing into
  either cell threw in the browser instead of announcing anything. Every cell
  a panel spans now carries that panel, so navigation across the span keeps
  announcing and highlighting it; the panel is still one plot, reported once
  per cell it covers. A `0` in the layout matrix, and a panel the matrix
  declares but the user never drew, still emit an empty cell — those are
  genuinely blank. `par(mfrow)` and `par(mfcol)` grids cannot span and are
  unchanged.
* Base R: `heatmap()` of a matrix with no `dimnames` announces the row and
  column identities it actually draws. `heatmap()` clusters the rows and
  columns and then labels the reordered matrix with the *original* indices,
  `(1L:nr)[rowInd]`; maidr instead filled unnamed axes with a plain 1..n
  position sequence, so a default `heatmap(m)` announced "row 5" while
  sonifying the values of original row 2. Only the labels were affected — the
  values have been drawn from the same ordering since dendrogram support
  landed, which left the payload internally inconsistent as well as wrong
  against the figure. Unnamed axes now take their labels from that ordering,
  on both the row and the column axis, and `revC` (which every `symm = TRUE`
  call turns on) reverses labels and values together as before. Matrices that
  carry `dimnames` are unchanged, as are `Rowv = NA, Colv = NA` heatmaps and
  `image()`, none of which reorder anything, so 1..n is what they draw.
* ggplot2: a grouped `geom_line()` keeps its highlight when another layer in
  the same panel also draws polylines. A grouped line draws all of its curves
  as one grob that gridSVG splits per curve, while a sibling `geom_smooth()`
  contributes grobs of its own; the layer's selector was picked by indexing
  that flat panel-wide list of grobs by the layer's position among line
  layers, so `geom_line(aes(colour = g)) + geom_smooth()` emitted three series
  and one selector. The frontend requires one selector per series and drops
  the whole layer's highlight otherwise, so nothing on screen moved as the
  reader walked any of the three lines. The layer's own grob is now resolved
  first and its curves enumerated from it, giving one selector per series; two
  line layers in one panel likewise each resolve to their own grob. When the
  curves cannot be lined up with the series, no selector is emitted rather
  than one of the wrong length.
* ggplot2: a faceted stacked bar whose facet column contains `NA` exports
  again. ggplot2 draws a real extra panel for the missing value, but the
  per-panel subset picked its rows with `==`, which answers `NA` for exactly
  those rows, and `[` turns an `NA` index into a fabricated all-`NA` row — so
  one missing facet value contaminated every panel, not only its own.
  `save_html()` aborted with `argument 1 is not a vector` and wrote no file at
  all; `geom_col()` and `stat = "identity"` were affected, `stat = "count"`
  was not. Each panel now reads only its own rows, the missing-value panel
  reads the rows whose facet value is `NA`, and it is announced as "NA" — the
  same two characters ggplot2 prints on its strip. Two neighbouring
  assumptions in the same layer go with it: the values are no longer paired
  with the drawn rectangles row by row once the two frames differ in length (a
  layer carrying its own `data =` argument used to announce categories it
  never drew), and a row ggplot2 could not position, such as one with a
  missing `y`, no longer counts as part of the layer.
* ggplot2: a faceted line plot on a transformed x scale announces the data
  values again instead of the transformed positions behind them. Under
  `facet_wrap()` plus `scale_x_log10()`, points labelled 1, 10, 100 and 1000
  on the axis were read out as 0, 1, 2 and 3; `scale_x_reverse()` negated
  every value and `scale_x_sqrt()` reported square roots. Panels now put the
  data through the same transformation the scale applied before matching, so
  what is announced matches the drawn axis. Faceted panels also read break
  labels off their own scale rather than the first panel's, which matters
  under `scales = "free_x"`. Untransformed, date and date-time faceted panels
  are unchanged, as are all unfaceted line plots.
* ggplot2: a facet level that drew nothing no longer breaks the chart's
  highlighting. A layer with no highlight target was emitting an empty
  selector list, and the frontend passes that value straight to
  `document.querySelectorAll()`, where an empty selector raises a
  `SyntaxError` inside the trace it was building. On a histogram, stacked bar
  or dodged bar under `facet_wrap(~g, drop = FALSE)` with an unused level,
  keyboard navigation then produced no highlight anywhere in the figure,
  while the chart still looked correct. Such a layer now omits the field
  instead, which is the value the frontend reads as "nothing to highlight".
* ggplot2: an empty facet panel no longer emits a layer describing nothing.
  A processor that drew nothing in a panel returns no data, and that was
  being wrapped into a single empty series, so a reader entering the panel
  was told it held a plot and then heard its fields announced as undefined,
  with the sonification failing on a non-finite value. The panel now carries
  no layers, the same shape a Base R `layout()` cell with no plot already
  has.
* ggplot2: a grouped smooth is described as one series per curve.
  `geom_smooth(aes(colour = g))` draws a curve per group, but the payload
  concatenated all of them into a single undifferentiated series with no `z`,
  so a reader walked off the end of one curve into the start of the next with
  nothing announced in between. The layer also carried a single selector
  aimed at one group's polyline, leaving three times as many data points as
  the highlighted line had vertices. Each group is now its own series, named
  after the group and labelled with the legend title, with its own selector.
  `geom_density()` splits the same way, including when the grouping is mapped
  to `fill`.
* LaTeX in MAIDR's AI chat responses renders styled again. MAIDR 3.75.1 split
  KaTeX out of `maidr.css` — which became a placeholder with no rules in it —
  into `maidr-math.css`, which `maidr.js` fetches at runtime from whichever
  directory it was itself loaded from. The bundled assets tracked that release
  without picking up the new file, so `maidr.css` was still linked (styling
  nothing) and the stylesheet that does style mathematics was absent. The
  bundle now ships `maidr-math.css` beside `maidr.js`, and no stylesheet is
  linked: MAIDR styles its interface at runtime and fetches that one file for
  itself. Its embedded KaTeX web fonts are still stripped to keep the installed
  package under CRAN's size limit, so glyphs fall back to system fonts while
  the layout rules — spacing, fractions, radicals, delimiters — are intact.

* ggplot2: histogram, stacked bar, dodged bar, and smooth layers no longer
  invent a highlight target when the grob lookup finds nothing. A facet level
  with no observations (`facet_wrap(~g, drop = FALSE)`), a zero-row layer, and
  a segmented bar under `coord_polar()` all draw no marks, and these four
  layers answered with a guessed element id instead of no selector at all.
  The guess never matched for the three rect layers, so the payload looked
  healthy while the layer highlighted nothing; for smooth it was worse, since
  the guessed id was byte-identical to the first panel's, and the empty panel
  highlighted another panel's fitted line. They now emit no selector, matching
  bar, point, box plot, line, heat map, and candlestick layers.
* ggplot2: a dodged `geom_bar()` no longer highlights the wrong bar when some
  (x, fill) combinations are empty. The layer emitted only the combinations it
  actually drew, so `ggplot(mpg, aes(class, fill = drv)) + geom_bar(position =
  "dodge")` produced series of five, four and three values against a chart of
  seven categories. MAIDR walks one flat list of rects column by column and
  sizes that walk from the payload, so a ragged payload claimed fifteen bars
  where twelve exist: the cursor overran and every bar after the first empty
  cell highlighted its neighbour, while position three meant `pickup` in one
  series and `minivan` in the next. Absent combinations are now announced as
  zero, which keeps each series one entry per category so the same position
  means the same category in all of them, and which is the honest value for a
  cross-tabulation -- a cell `stat = "count"` never drew is a cell whose count
  really is zero, and MAIDR gives it no highlight because there is no bar to
  highlight. Bars supplied through `geom_col()` are left alone: a row the
  caller omitted has no value, and inventing a zero for it would invent data.
  Dodged counts also asked for the wrong per-column highlight direction, which
  put every series on its neighbour's bars even when no combination was empty.
* ggplot2: a dodged `geom_bar()` now announces its categories in the plotted
  order. The layer sorted them as text, which disagreed with the chart twice
  over: a factor is laid out in level order, so reversed or custom levels
  described column one of the payload against column three of the chart, and a
  number sorts with 10 before 2.
* ggplot2: a faceted panel no longer discards the display hints its layers
  emit. The panel entry was assembled from a fixed list of keys, so anything
  else a processor returned -- `domMapping`, `orientation`, the box plot's IQR
  direction -- was dropped, and every panel fell back to defaults the
  unfaceted plot never uses. A faceted dodged `geom_bar()` therefore
  highlighted its neighbour's bars in every panel. The 'patchwork' path
  already carried these fields; the facet path now matches it.
* Base R: `curve()` renders as an interactive line plot instead of a static
  image. The call was recorded, but the adapter had no layer type for it, so
  it typed as "unknown" and the whole figure fell back to a picture with no
  sonification, braille, or keyboard navigation. It now types as the same
  line layer `plot(x, y, type = "l")` produces, and the announced points are
  the ones `curve()` returned after drawing them, so they cannot drift from
  what was plotted. The axis labels `curve()` derives for itself -- the
  variable name and the deparsed expression -- are announced too. Draw types
  that are not a polyline (`type = "p"`, `"b"`, `"s"`, ...) and
  `curve(add = TRUE)` keep the static fallback.
* Base R: `curve()` called from inside a function sees that function's
  variables. `curve()` resolves the free variables of its expression against
  the calling frame, which through maidr's wrapper was the wrapper's own
  frame, so `f <- function(k) curve(sin(k * x), from = 0, to = pi)` failed
  with "object 'k' not found" -- a call that works in plain R. It only
  appeared to work at top level, where the global environment is on the
  package's search chain.
* ggplot2: a 'patchwork' panel no longer loses the axis labels ggplot2
  computes. Each leaf's layout was read before the leaf was built, and under
  ggplot2 v4 an unbuilt plot carries only the labels an explicit `labs()` set,
  so a `geom_bar()` inside a composition announced the placeholder "Y" in
  place of "count". The leaf is now built first and its layout read from the
  result.
* ggplot2: faceted plots no longer lose their axis labels. Each panel rebuilt
  its own axes from the unbuilt plot, which under ggplot2 v4 records only the
  labels an explicit `labs()` set -- everything ggplot2 derives while building
  was dropped. Every faceted panel therefore announced the placeholder
  "Categories" for x and nothing at all for y, so a faceted `geom_bar()` said
  "Categories is suv" where the unfaceted one says "class is suv, count is
  62". Panels now keep the labels their layers resolved, including the legend
  title. A panel collapses all of its layers into one description, so the
  labels are assembled across them: a plot whose first layer is ungrouped and
  whose second is grouped -- `geom_point()` under `geom_line(aes(colour =
  g))`, say -- still wrote the group into the data while carrying no title
  for it, and MAIDR announced the generic word "Group".
* ggplot2: a multi-series line plot now announces its legend title instead of
  the word "Group". The layer already emitted a per-series group name, which
  MAIDR reads out as "<label> is <value>", but the payload carried no label
  for it, so the viewer fell back to a generic placeholder and the title set
  by `labs(colour = ...)` -- or the mapped column name when no title was set
  -- was never spoken, brailled, or shown in the chart description. Stacked
  bar, dodged bar, and heatmap layers already carried theirs; line layers now
  do too.
* patchwork: layer ids are unique across a whole composition. Every leaf
  numbered its layers from 1, so a 2x2 patchwork emitted four layers all
  called `maidr-layer-1`. The frontend keys its per-figure number-format map
  on the bare layer id, so the last leaf's formats overwrote every other
  leaf's and the wrong ones were announced; a candlestick-over-volume
  composition was worse, because collapsing its two panels into one subplot
  put two identically named layers side by side. Ids now carry the panel's
  grid cell.
* ggplot2: axis number formats are honoured inside a 'patchwork'. A
  `scale_y_continuous(labels = ...)` wrapper was applied on a single plot and
  on a faceted plot, and silently ignored the moment the same plot went into
  a composition, so values were announced unformatted -- currency read as a
  bare number, percentages without their sign. The patchwork path never
  extracted a format config or ran the `validate_axes()` contract check the
  other two paths run; it now does both, per leaf, so each plot in a
  composition keeps its own formats.
* Base R: one annotation overlay no longer silences a whole multi-panel
  figure. A `segments()`, `arrows()`, `rect()` or `polygon()` call can carry
  data maidr cannot read, so the panel holding it is still declined rather
  than described incompletely -- but the decline used to take the entire
  figure with it. A single arrow pointing at an outlier in one cell of a
  `par(mfrow = c(2, 2))` grid cost the other three panels their
  sonification, braille and keyboard navigation, and left the reader with a
  static image. Only the annotated panel now goes quiet; it is still drawn,
  the rest of the grid stays interactive, and the warning names the panel
  that fell back. Single-panel figures, figures whose every panel is
  annotated, overlays drawn outside the exported grid, and grids holding a
  plot type maidr cannot read at all still fall back as a whole, as before.
* Base R: highlighting in a multi-panel figure now follows the panel actually
  drawn. Only the panel-visible plot groups are replayed, so the exported SVG
  numbers its panels in replay order, but each panel looked its elements up by
  the plot group's own index. One skipped group -- a plot drawn before the
  `par(mfrow = ...)` call, or a page that scrolled off when more plots were
  drawn than the grid holds -- shifted every later panel, so panel 1 lit up
  panel 2's bars and the last panel highlighted nothing at all. This affected
  `mfrow`, `mfcol` and `layout()` grids alike.
* Base R: a `heatmap()` drawn with `revC` -- which every `symm = TRUE` call
  turns on, since `Colv` defaults to `"Rowv"` there -- is no longer described
  upside down. `revC` flips the drawing so the first reordered row lands at
  the top, but it is not part of the ordering `heatmap()` reports, so the
  emitted grid was reversed anyway: two calls differing only in `revC`
  produced byte-identical data for mirror-image figures, and every row label
  named the row on the opposite side of the plot.
* ggplot2: a faceted bar chart on a continuous, `Date` or `POSIXct` x axis no
  longer announces the wrong x value. Each panel labelled its bars by using
  the bar's x position as an INDEX into that panel's axis break labels, which
  is only meaningful for a discrete axis where those positions are category
  numbers. On a numeric axis the positions are the values themselves, so
  `c(2, 4, 6)` was announced as "2", "6", "6", `c(1, 2, 3)` lost its first
  label entirely, and a `Date` axis announced raw day counts ("19723") rather
  than dates. Non-discrete panels now report their own values, formatted the
  same way an unfaceted chart formats them.
* ggplot2: bar, point, line, box, histogram, smooth, stacked-bar, dodged-bar,
  heatmap and candlestick plots inside a NESTED 'patchwork' are no longer
  inert. Each of these carried its own panel lookup that scanned only the top
  level of the composition and addressed panels by name, but `(p1 | p2) / p3`
  keeps the inner row's panels inside a child table and leaves only a
  placeholder at the top, and panel names repeat across nesting levels
  anyway. A nested leaf therefore failed in one of two ways: bar, point, box,
  line, heatmap and candlestick emitted no selector at all, while histogram,
  smooth, stacked bar and dodged bar fell through to a fabricated selector
  that matched nothing -- the worse of the two, because the payload looks
  healthy while the layer highlights nothing. Every processor now resolves
  its panel through the same recursive walk the violin processor already
  used, and each leaf addresses its own panel. Flat compositions and faceted
  plots are unaffected.
* The startup message no longer promises something the package does not do.
  It told every user, on every `library(maidr)`, that plots are displayed in
  the interactive viewer by default. That is true for ggplot2, which hooks
  `print.ggplot`, and has never been true for Base R: those plots are
  recorded to a hidden device and wait for an explicit `show()`. The message
  now says which is which.
* Asset loading: the internet probe is no longer cached for the whole
  session. It was probed once and never re-checked, so the first answer
  decided CDN-versus-inline for the life of the process -- a transient
  failure inlined the bundle into every later document, and a machine that
  went offline after a successful probe kept emitting CDN references, leaving
  plots dead in the browser exactly when the user could not debug them. The
  result now expires after five minutes, which still costs one probe per
  render rather than one per plot.
* knitr: turning interception off mid-document no longer leaves recorded Base
  R calls behind. The hook returned early when interception was disabled
  without clearing the device, unlike the sibling branch for non-HTML output,
  so a document that plotted, called `maidr_off()`, then called `maidr_on()`
  again folded the earlier calls into the next render as phantom layers.
* Base R: a plot drawn in a loop now renders the iteration it recorded. When
  an argument cannot be evaluated where the call is intercepted -- the shape
  `plot(y ~ x, data = d, subset = grp == g)`, which mixes a column of `data`
  with a variable from the loop -- maidr records the unevaluated expressions
  and re-evaluates them at render time. It recorded the caller's frame to
  re-evaluate them in, and R reuses ONE frame for the whole loop, so by
  render time every iteration saw the LAST iteration's values:
  `for (g in c("a", "b")) plot(y ~ x, data = d, subset = grp == g)` drew
  `grp == "b"` in both panels, with no error and no warning. The values the
  recorded expressions name are now captured when the call is made, so each
  panel replays its own data. Only the names actually referenced are
  captured, into a child of the caller's frame, so everything else still
  resolves as before and active bindings are left to the caller. Applies to
  every deferred path: `plot()`, `boxplot()`, `barplot()`, `curve()`,
  `lines()`, `points()` and `chartSeries()`.
* ggplot2: a violin plot combined with 'patchwork' is no longer silent. The
  leaf emitted a subplot with no layers at all -- no sonification, no
  braille, no highlighting for that panel -- because the processor skipped
  every call that carried a panel context, a guard meant only for faceted
  violins. Patchwork leaves now emit the same `violin_box` and `violin_kde`
  layers a standalone violin does, with selectors scoped to their own panel
  and KDE highlight coordinates read from their own panel's viewport,
  including for violins nested inside a patchwork row. Faceted violins
  remain unsupported.
* ggplot2: a patchwork containing a faceted plot now pairs each of its other
  plots with the right panel. A faceted plot draws one panel per facet cell
  while still counting as one plot, so every plot after it was described
  over someone else's panel, and the surplus panels repeated the
  last-added plot's data -- the same numbers announced in three places, only
  one of them reachable. Panels are now consumed per plot, so each is
  announced once, on its own panel.
* ggplot2: the box statistics of a violin plot now describe the group they
  are announced with. The quartiles were recomputed from the drawn geometry
  rather than read from ggplot2's own `stat_boxplot` output, so a violin
  split by `fill` announced one set of class-wide numbers over every one of
  its dodged violins -- `aes(class, hwy, fill = drv)` emitted 7 labels for
  12 violins, each repeated. A `coord_flip()` violin read its labels off the
  vertical axis, which is now the continuous one, and reported every
  quartile as 0. A violin on a continuous axis matched labels by position
  index, announcing a `7` for `cyl` that no car has. All three now report
  each group's own quartiles under its own label, dodged violins included.
* ggplot2: `geom_violin(width = 0)` no longer errors out of rendering with
  "missing value where TRUE/FALSE needed". A violin drawn with no width has
  nothing to scale the density against; it now renders, and any positive
  widths in the same layer still scale normally.
* ggplot2: a plot placed after an `inset_element()`, `free()` or
  `wrap_elements()` in a patchwork is described again. Those wrappers put a
  plot in a cell panel discovery does not recognise, so it contributes no
  panel -- but it was still counted as occupying one, which pushed every
  later plot onto somebody else's panel and the last of them off the end.
  `patchwork::free(p1) | p2` announced nothing for `p2` at all.
* ggplot2: one plot a processor cannot handle no longer aborts the whole
  patchwork. Rendering failed for the entire composition; now that panel is
  silent and the rest of the figure is still described.
* Shiny: `render_maidr()` renders Base R plots again. It branched on the
  expression's return value, which says nothing about whether anything was
  drawn -- `plot()` returns NULL invisibly, so it was treated as an empty
  reactive and rendered a silent blank, while `barplot()` and `hist()`
  return a non-plot value and errored the output slot with "Input must be a
  ggplot object". Only ggplot worked. `render_maidr()` now asks whether the
  expression actually recorded any drawing, so all three render. An
  expression that draws nothing and returns NULL still renders nothing.

* Base R: recorded plot calls now capture non-standard-evaluation arguments
  safely, so `curve(sin(x))` no longer errors or records stale values;
  replay evaluates them in the original environment.
* Base R: a multi-panel grid is no longer destroyed by the idiomatic
  trailing `par(mfrow = c(1, 1))` reset. A layout call issued after the
  last plot governs nothing that was drawn, so it no longer wins over the
  layout the panels were actually drawn under.
* Base R: `hist(x, plot = FALSE)` / `boxplot(x, plot = FALSE)` are no longer
  recorded as plot calls (previously they injected phantom layers into the
  next render).
* Base R: extracted bar data now always matches the rendered SVG order.
  `barplot()` no longer re-sorts labels alphabetically out of sync with the
  drawn bars, unnamed vectors keep call order, and the sorted arguments the
  wrapper draws are also what gets recorded and replayed.
* Base R: matrix `barplot()` without an explicit `beside` argument is now
  correctly detected as stacked (barplot's default), not simple bars.
* Base R: `legend.text` no longer contaminates stacked/dodged bar highlight
  selectors with the legend's swatch rectangles.
* Base R: `barplot(horiz = TRUE)` now emits `orientation = "horz"` with
  value/label roles swapped so announcements and navigation are correct.
* Base R: `heatmap()` now reproduces the dendrogram row/column reordering it
  draws with, `image()` no longer transposes rows and columns, both accept
  positional matrix arguments, and per-cell selectors fix the vertically
  mirrored cell highlighting.
* Base R: `hist()` recomputation now honours `right`, `include.lowest`, and
  `nclass`, and probability/density histograms announce densities instead of
  counts.
* Base R: `plot(v, type = "l")`, `lines(v)`, and `plot(v)` single-vector
  calls no longer crash or emit NA values; graphical parameters can no
  longer be mistaken for data arguments.
* Base R: box plot outlier highlights now follow the actual drawing order
  instead of assuming lower outliers are drawn first.
* Base R: multiline selectors are ordered numerically, so plots with ten or
  more series map each series to the correct polyline.
* Base R: multipanel handling fixes - `layout()`-based grids are treated as
  multipanel, plots beyond the grid follow R's new-page behaviour, plots
  drawn before the layout call are excluded, per-panel `axis()` format
  configs stay per-panel, empty grid cells serialize as valid subplots, and
  processor fields (orientation, domMapping) are preserved.
* Base R: fallback replay to the native device now replays `par()`/
  `layout()` calls in original order and strips maidr-internal arguments.
* Base R: `title`/`subtitle` extraction no longer partial-matches unrelated
  arguments (e.g. `subset`) and tolerates non-character values.
* Base R: unsupported data-bearing overlays (`polygon()`, `rect()`,
  `segments()`, ...) now trigger the documented fallback instead of being
  silently dropped from the accessible output.
* Base R: `plot(y ~ x, data = d, subset = ...)` and
  `boxplot(y ~ g, data = d, subset = ...)` work again. The formula methods
  resolve `subset` relative to `parent.frame()`, which the recording
  wrapper displaced, so these calls failed with "object 'g' not found" and
  "..3 used in an incorrect context" even though they work in plain R.
* Base R: `matplot(m)` on a matrix again emits one series per column.
  Routing a lone matrix through `xy.coords()` read a two-column matrix as
  an x/y pair, so every series but one vanished from the accessible output
  and the first series' values were announced as x coordinates.
* Base R: `barplot(x, plot = FALSE)` is no longer recorded as a plot call.
  The rule was applied to the generic wrapper only, and `barplot()` has its
  own code path.
* Base R: `cancel_auto_show()` removes its task callback by name. It used
  the index `addTaskCallback()` returned, which is a position in R's
  callback list, so an unrelated package's callback could be removed
  instead.
* Base R: `maidr::chartSeries()` is recorded even when 'quantmod' is loaded
  after 'maidr'. (Corrected in the development version: this entry
  originally claimed `chartSeries()` calls were recorded whenever 'quantmod'
  was loaded after 'maidr', which was never true of `library(quantmod)`.
  Attaching 'quantmod' after 'maidr' masks maidr's wrapper — see the
  development-version notes.)
* ggplot2: faceted box plots, histograms, smooths, heatmaps, and
  stacked/dodged bars no longer crash with "unused arguments"; extracted
  data and selectors are now scoped to each facet panel. Faceted violins
  stop crashing too, but they are skipped rather than made interactive:
  the facet combiner emits at most one layer per panel and so cannot carry
  a violin's `violin_box` + `violin_kde` pair.
* ggplot2: dodged bars accept expression aesthetics such as
  `aes(fill = factor(cyl))`. Aesthetics were resolved with
  `rlang::as_label()` and used as column names, so `data[["factor(cyl)"]]`
  was `NULL` and the plot died with "all arguments must have the same
  length". Aesthetics are now evaluated against the data, which also makes
  the row ordering match the drawn bars for expression aesthetics.
* ggplot2: each faceted box plot panel is announced with its own category
  names. Names were read from an unfiltered vector of axis positions
  indexed by position within the panel, so a panel drawing its boxes at
  positions 3 and 4 was labelled with the categories at positions 1 and 2 —
  correct quartiles under the wrong names.
* ggplot2: nested patchwork layouts (e.g. `(p1 | p2) / p3`) no longer drop
  panels from the accessible output.
* ggplot2: histogram and smooth layers extract their own layer's data
  instead of the first similarly-shaped layer in multi-layer plots.
* ggplot2: scatter point colour/grouping values are emitted again, faceted
  plots included. The category lookup compared a panel-filtered row count
  against the whole data set; the two never matched under faceting, so
  every faceted scatter announced raw hex codes (`#F8766D`) instead of
  category names.
* ggplot2: each faceted heat map panel reports its own cell values. Cells
  were looked up in the unfiltered source data by (x, y) label, which
  matches a row in every panel, and the first match won — so all panels
  reported panel 1's values.
* Base R: `layout()` matrices no longer count their empty `0` cells as
  panels when tracking device state, matching the panel grouping code.
* ggplot2: heatmap axis mappings follow factor level order instead of
  data-appearance order.
* ggplot2: `maidr_off()` now really disables RMarkdown interception, PDF and
  LaTeX output keep their figures, a second `maidr_on()` no longer risks
  infinite hook recursion, and non-HTML output uses the original knitr plot
  hook instead of hardcoding the markdown hook.
* Shiny/widgets: `show(as_widget = TRUE)` and widget rendering now support
  Base R plots, `render_maidr()` renders nothing (instead of erroring) for
  NULL reactives, and device storage is cleared on the shiny/widget paths.
* Rendering: maidr-data JSON keeps full numeric precision (previously values
  were silently rounded to 4 decimal digits), `NA` handling is unchanged,
  and non-ASCII text in iframes is UTF-8 safe on all locales.
* Rendering: plot IDs no longer consume random numbers, preserving
  `set.seed()` reproducibility of user scripts.
* `maidr_set_fallback()` now keeps unspecified settings instead of silently
  resetting them to defaults.
* Scale label mapping keys labels by actual break positions, fixing
  mislabeled categories with custom break subsets.

## Enhancements

* CDN assets are pinned to the bundled MAIDR.js version instead of
  `@latest`, so the emitted schema and frontend can no longer drift apart.
* Iframe height auto-resize now also works in RMarkdown documents (the
  postMessage listener previously shipped only with the htmlwidgets
  binding).

## Performance

* ggplot2 plots are built once per render instead of three times; the
  faceted and patchwork paths reuse the built plot instead of rebuilding it
  per layer.
* Base R renders reuse the replayed gtable instead of re-replaying every
  recorded call on each access.
* Candlestick SVG post-processing parses the document once instead of five
  times.
* The multi-megabyte bundled JS/CSS assets are read once per session
  instead of once per rendered plot, and the offline-detection probe is
  cached per session instead of hitting the network for every plot.

# maidr 0.4.0

## New Features

* Added candlestick (OHLC) chart support for 'ggplot2' via the
  'tidyquant' package's `geom_candlestick()`. Each candle is exposed as a
  single navigable element with `open`, `high`, `low`, `close`, optional
  `volume`, and computed `trend` (Bull / Bear / Neutral) and
  `volatility` (high − low) fields.
* Added Base R candlestick (OHLC) chart support via
  `quantmod::chartSeries(x, type = "candlesticks")`. The xts/zoo input is
  validated with `quantmod::has.OHLC()` and each row is emitted as a
  navigable `CandlestickPoint` with `value` (ISO date), `open`, `high`,
  `low`, `close`, computed `trend` (Bull / Bear / Neutral) and
  `volatility` (high − low) fields, plus optional `volume` when
  `quantmod::has.Vo()` is `TRUE`.

# maidr 0.2.0

## New Features

* Added violin plot support for 'ggplot2' (`geom_violin()`), including both
  vertical and horizontal orientations.
* Violin plots produce two interactive layers: a box-summary layer
  (`violin_box`) with min, Q1, median, Q3, max highlights, and a KDE
  density-curve layer (`violin_kde`) with navigable density points.
* Added Ramer-Douglas-Peucker (RDP) curve simplification to reduce KDE
  density points to ~30 per violin while preserving shape fidelity.
* SVG coordinate injection for violin KDE points enables accurate highlight
  positioning in the maidr frontend.

## Enhancements

* Renamed option `maidr.enabled` to `maidr.auto_show` for clarity.
* Added `domMapping.iqrDirection` support for violin box layers, aligning
  with the existing box plot pattern for correct Q1/Q3 highlighting under
  gridSVG Y-flip transforms.
* Added plot augmentation API (`augment_plot()`, `needs_augmentation()`) to
  the `LayerProcessor` base class, enabling processors to inject additional
  geom layers before rendering.
* Added multi-layer expansion in the orchestrator for plot types that produce
  more than one maidr layer from a single geom.

## Documentation

* Added violin plot examples to `show()`, `save_html()`, vignettes, and
  example scripts.
* Updated DESCRIPTION to list violin plots as a supported type.

# maidr 0.1.1

Resubmission after CRAN archival. Fixes CRAN policy compliance issues.

## Bug Fixes

* Removed all `assign(..., envir = .GlobalEnv)` calls that violated CRAN policy.
  Base R function wrappers are now installed into the package namespace during
  `.onLoad` and controlled via an active/inactive flag, eliminating any
  modification of the user's global environment.
* Removed `attach()` usage that produced R CMD check NOTE.
* Fixed Rd documentation warning caused by unicode escape sequences in
  `prefix_to_currency_code` parameter documentation.

## Enhancements

* Added subtitle and caption support to the MAIDR payload for both
  'ggplot2' and Base R plots.
* Added `scales` formatting support for Base R axis labels
  (currency, percent, comma, scientific notation).

# maidr 0.1.0

Initial CRAN release.

## Features

* `show()` - Display interactive, accessible visualizations from ggplot2 or
  Base R plots with keyboard navigation and screen reader support
* `save_html()` - Export accessible visualizations to standalone HTML files
* `render_maidr()` and `maidr_output()` - Shiny integration for interactive
  web applications

## Supported Plot Types

### ggplot2 - Basic
* Bar charts (`geom_bar()`, `geom_col()`)
* Grouped/dodged bar charts (`position = "dodge"`)
* Stacked bar charts (`position = "stack"`)
* Histograms (`geom_histogram()`)
* Line plots (`geom_line()`)
* Scatter plots (`geom_point()`)
* Box plots (`geom_boxplot()`)
* Heatmaps (`geom_tile()`)
* Smooth/density curves (`geom_smooth()`, `geom_density()`)

### ggplot2 - Advanced
* Faceted plots (`facet_wrap()`, `facet_grid()`)
* Multi-panel layouts with patchwork package
* Multi-layered plots (e.g., histogram + density, scatter + smooth)

### Base R - Basic
* Bar plots (`barplot()`)
* Grouped bar plots (`beside = TRUE`)
* Stacked bar plots (`beside = FALSE`)
* Histograms (`hist()`)
* Line plots (`plot()` with `type = "l"`, `lines()`)
* Scatter plots (`plot()`)
* Box plots (`boxplot()`)
* Heatmaps (`image()`)
* Density curves (`lines(density())`)

### Base R - Advanced
* Multi-panel plots (`par(mfrow)`, `par(mfcol)`)
* Faceted-style plots (using `par()` with loops)
* Multi-layered plots (sequential plotting calls)

## Accessibility Features

* Keyboard navigation for data exploration
* Screen reader compatibility with ARIA labels
* Sonification (audio representation of data)
* Multiple sensory modalities for data access
