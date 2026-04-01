# maidr: Multimodal Access and Interactive Data Representation

The 'maidr' package provides accessible, interactive visualizations
through the MAIDR (Multimodal Access and Interactive Data
Representation) system. It converts 'ggplot2' and Base R plots into
accessible HTML/SVG formats with keyboard navigation, screen reader
support, and sonification capabilities. This enables users with visual
impairments to independently explore and understand data visualizations
through multiple sensory modalities.

## Main Functions

- [`show`](https://r.maidr.ai/reference/show.md): Display an interactive
  MAIDR plot in the browser or RStudio Viewer

- [`save_html`](https://r.maidr.ai/reference/save_html.md): Save a plot
  as a standalone HTML file

- [`run_example`](https://r.maidr.ai/reference/run_example.md): Run
  interactive example plots

- [`maidr_on`](https://r.maidr.ai/reference/maidr_on.md): Enable
  automatic MAIDR interception in RMarkdown

- [`maidr_off`](https://r.maidr.ai/reference/maidr_off.md): Disable
  automatic MAIDR interception

- [`render_maidr`](https://r.maidr.ai/reference/render_maidr.md): Render
  MAIDR plots in Shiny applications

- [`maidr_output`](https://r.maidr.ai/reference/maidr_output.md): Create
  MAIDR output container for Shiny UI

## Supported Plot Types

The package supports a wide variety of plot types from both 'ggplot2'
and Base R plotting systems:

**ggplot2 plots:**

- Bar charts (simple, grouped, stacked) -
  [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html),
  [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)

- Histograms -
  [`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html)

- Scatter plots -
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)

- Line plots -
  [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)

- Box plots -
  [`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)

- Violin plots -
  [`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)

- Heat maps -
  [`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)

- Density/smooth curves -
  [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html),
  [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)

- Faceted plots -
  [`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html),
  [`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html)

- Multi-panel layouts (via 'patchwork' package)

- Multi-layered plot combinations

**Base R plots:**

- Bar plots (simple, grouped, stacked) -
  [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)

- Histograms -
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)

- Scatter and line plots -
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`points()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md)

- Box plots -
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)

- Heat maps -
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md),
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)

- Multi-panel layouts - `par(mfrow)`, `par(mfcol)`

## Accessibility Features

- **Keyboard Navigation**: Use arrow keys to explore data points

- **Screen Reader Support**: ARIA labels and live regions for
  announcements

- **Sonification**: Audio representation of data patterns

- **Text Summaries**: Automatic statistical descriptions

- **Grid Navigation**: Efficient exploration of scatter plots

## Integration

The package integrates seamlessly with:

- **RStudio**: Direct display in the Viewer pane

- **RMarkdown/Quarto**: Automatic rendering with
  [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md)

- **Shiny**: Interactive plots in Shiny apps via
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md)

- **Standalone HTML**: Export plots for sharing with
  [`save_html()`](https://r.maidr.ai/reference/save_html.md)

## Getting Started

To create your first accessible plot:

    library(maidr)
    library(ggplot2)

    # Create a ggplot2 plot
    p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
      geom_boxplot()

    # Display as interactive MAIDR plot
    show(p)

    # Or save to HTML file
    save_html(p, file = "my_plot.html")

For Base R plots:

    library(maidr)

    # Create a Base R plot
    barplot(table(mtcars$cyl))

    # Display as interactive MAIDR plot
    show()

## Learn More

- Package website: <https://r.maidr.ai/>

- MAIDR project: <https://maidr.ai/>

- GitHub repository: <https://github.com/xability/r-maidr>

- Get started:
  [`vignette("getting-started", package = "maidr")`](https://r.maidr.ai/articles/getting-started.md)

- Shiny integration:
  [`vignette("shiny-integration", package = "maidr")`](https://r.maidr.ai/articles/shiny-integration.md)

## See also

Useful links:

- <https://github.com/xability/r-maidr>

- <https://r.maidr.ai/>

- Report bugs at <https://github.com/xability/r-maidr/issues>

## Author

**Maintainer**: Niranjan Kalaiselvan <nk46@illinois.edu>

Authors:

- JooYoung Seo <jseo1005@illinois.edu> \[copyright holder\]
