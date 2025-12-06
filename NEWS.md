# maidr 0.1.0

Initial CRAN release.

## Features

* `show()` - Display interactive, accessible visualizations from ggplot2 or
  Base R plots with keyboard navigation and screen reader support
* `save_html()` - Export accessible visualizations to standalone HTML files
* `render_maidr()` and `maidr_output()` - Shiny integration for interactive
  web applications

## Supported Plot Types

### ggplot2
* Bar charts (`geom_bar()`, `geom_col()`)
* Grouped/dodged bar charts
* Stacked bar charts
* Histograms (`geom_histogram()`)
* Line plots (`geom_line()`)
* Scatter plots (`geom_point()`)
* Box plots (`geom_boxplot()`)
* Heatmaps (`geom_tile()`)
* Smooth curves (`geom_smooth()`)

### Base R
* Bar plots (`barplot()`)
* Grouped and stacked bar plots
* Histograms (`hist()`)
* Line plots (`plot()` with `type = "l"`, `lines()`)
* Scatter plots (`plot()`)
* Box plots (`boxplot()`)
* Heatmaps (`image()`)
* Multi-panel plots (`par(mfrow)`, `par(mfcol)`)

## Accessibility Features

* Keyboard navigation for data exploration
* Screen reader compatibility with ARIA labels
* Sonification (audio representation of data)
* Multiple sensory modalities for data access
