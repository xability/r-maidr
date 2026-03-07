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
