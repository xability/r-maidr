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
