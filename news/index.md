# Changelog

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
