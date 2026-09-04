# Changelog

## maidr (development version)

### New Features

#### ggplot2

- Added pie chart support: a
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)
  layer under `coord_polar("y")` or `coord_radial(theta = "y")` is
  emitted as a `pie` layer, one navigable slice per wedge.
  `coord_polar("x")` and multi-ring charts keep their bar reading.
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

- Added Base R
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) support,
  one navigable slice per wedge. Text grobs with an `NA` justification
  are repaired so
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) exports
  through gridSVG.
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
  maidr build that supports the display, which is later than the bundled
  4.6.0.
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

#### ggplot2

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

### Enhancements

- Bundled MAIDR.js updated from 3.72.1 to 4.6.0, and CDN assets are
  pinned to the bundled version instead of `@latest`.
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
  own title rather than its file’s. The test suite now rejects the three
  roxygen layouts that produce such pages, and `tools/document.R`
  regenerates `man/` with the pinned roxygen2 release.
- The README lists every roadmap-added layer type under “Experimental
  Plot Types”, the examples gallery has a worked example for each Base R
  and ggplot2 chart, and `use_cdn` is documented as it behaves:
  [`show()`](https://r.maidr.ai/reference/show.md) and
  [`save_html()`](https://r.maidr.ai/reference/save_html.md) use the
  bundled files by default (with a `lib/` folder beside the saved file),
  while widgets, knitr and Shiny auto-detect the CDN.
- The getting-started vignette tells Quarto `revealjs` authors how to
  keep off-slide charts out of the tab order.

### Performance

- ggplot2 layer processors reuse one built plot and gtable per render,
  and the faceted and patchwork paths do the same per panel and leaf.
- Base R renders cache the replayed gtable instead of re-replaying every
  recorded call; candlestick SVG post-processing parses the document
  once; the bundled JS/CSS is read once per session.

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
