# maidr (development version)

## Bug Fixes

* ggplot2: bar, point, line, box, histogram, smooth, stacked-bar, dodged-bar,
  heatmap and candlestick plots inside a NESTED 'patchwork' are no longer
  inert. Each of these carried its own panel lookup that scanned only the top
  level of the composition and addressed panels by name, but `(p1 | p2) / p3`
  keeps the inner row's panels inside a child table and leaves only a
  placeholder at the top, and panel names repeat across nesting levels
  anyway. Nested leaves therefore emitted an empty selector list, which the
  browser rejects outright -- so a single nested panel took down the whole
  figure, including the panels whose selectors were fine. Every processor now
  resolves its panel through the same recursive walk the violin processor
  already used. Flat compositions and faceted plots are unaffected.
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
* Base R: `chartSeries()` calls are now recorded even when 'quantmod' is
  loaded after 'maidr'.
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
