# Changelog

## maidr (development version)

### New Features

- [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
  now keeps the confidence band it draws. `se = TRUE` is the default,
  and the band is the reason the layer is drawn rather than a plain
  line: it says how much of the fitted trend the data supports.
  `StatSmooth` computes it into `ymin`/`ymax` alongside the fitted
  value, and maidr read only the fit – so a chart that otherwise worked
  was silently missing the half a reader needs to judge it. The band is
  emitted as its own `error_bar` layer, the shape MAIDR reads today and
  the one the Python binding already produces for the same question. A
  hue-split chart gets one band per curve, named after its group,
  because an `error_bar` layer is a flat sequence: concatenating them
  would walk a reader off the end of one curve into the start of the
  next with nothing announced between. A density curve is left alone –
  `StatDensity` fills the same two columns with the extent of its fill
  rather than an uncertainty, so the rule asks the layer’s stat rather
  than its columns. A faceted smooth is unchanged for now, since a facet
  panel carries a single layer type by construction.

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
