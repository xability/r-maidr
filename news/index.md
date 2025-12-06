# Changelog

## maidr 0.1.0

Initial CRAN release.

### Features

- [`show()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/show.md) -
  Display interactive, accessible visualizations from ggplot2 or Base R
  plots with keyboard navigation and screen reader support
- [`save_html()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/save_html.md) -
  Export accessible visualizations to standalone HTML files
- [`render_maidr()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/render_maidr.md)
  and
  [`maidr_output()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/maidr_output.md) -
  Shiny integration for interactive web applications

### Supported Plot Types

#### ggplot2

- Bar charts
  ([`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html),
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html))
- Grouped/dodged bar charts
- Stacked bar charts
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
- Smooth curves
  ([`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html))

#### Base R

- Bar plots ([`barplot()`](https://rdrr.io/r/graphics/barplot.html))
- Grouped and stacked bar plots
- Histograms ([`hist()`](https://rdrr.io/r/graphics/hist.html))
- Line plots ([`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  with `type = "l"`, [`lines()`](https://rdrr.io/r/graphics/lines.html))
- Scatter plots
  ([`plot()`](https://rdrr.io/r/graphics/plot.default.html))
- Box plots ([`boxplot()`](https://rdrr.io/r/graphics/boxplot.html))
- Heatmaps ([`image()`](https://rdrr.io/r/graphics/image.html))
- Multi-panel plots (`par(mfrow)`, `par(mfcol)`)

### Accessibility Features

- Keyboard navigation for data exploration
- Screen reader compatibility with ARIA labels
- Sonification (audio representation of data)
- Multiple sensory modalities for data access
