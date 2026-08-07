# Changelog

## maidr (development version)

### Bug Fixes

- knitr: turning interception off mid-document no longer leaves recorded
  Base R calls behind. The hook returned early when interception was
  disabled without clearing the device, unlike the sibling branch for
  non-HTML output, so a document that plotted, called
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md), then
  called [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) again
  folded the earlier calls into the next render as phantom layers.

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
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  calls are now recorded even when ‘quantmod’ is loaded after ‘maidr’.

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
