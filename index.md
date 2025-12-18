# maidr

## Overview

maidr (Multimodal Access and Interactive Data Representation) makes data
visualizations accessible to users with visual impairments. It converts
ggplot2 and Base R plots into interactive, accessible HTML/SVG formats
with keyboard navigation, screen reader support, and sonification.

The package provides two main functions:

- [`show()`](https://r.maidr.ai/reference/show.md) displays an
  interactive accessible plot in RStudio Viewer or browser
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) exports a
  plot as a standalone HTML file

## Installation

``` r
# Install from CRAN (coming soon)
install.packages("maidr")

# Or install development version from GitHub
pak::pak("xability/r-maidr")

# Alternative: using pacman (auto-installs if missing)
pacman::p_load_gh("xability/r-maidr")
```

## Usage

### ggplot2

``` r
library(maidr)
library(ggplot2)

p <- ggplot(mpg, aes(x = class)) +
  geom_bar(fill = "steelblue") +
  labs(title = "Vehicle Classes", x = "Class", y = "Count")

# Display interactive accessible plot
show(p)

# Or save to file
save_html(p, "vehicle_classes.html")
```

### Base R

``` r
library(maidr)

# Create plot first
barplot(
  table(mtcars$cyl),
  main = "Cars by Cylinder Count",
  xlab = "Cylinders",
  ylab = "Count"
)

# Then call show() without arguments
show()
```

## Supported plot types

maidr supports a wide range of visualization types in both ggplot2 and
Base R:

### Basic Plot Types

| Plot Type           | ggplot2                                                                                                                                                    | Base R                                                                 |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Bar charts          | [`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html), [`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)               | [`barplot()`](https://rdrr.io/r/graphics/barplot.html)                 |
| Grouped/Dodged bars | `position = "dodge"`                                                                                                                                       | `beside = TRUE`                                                        |
| Stacked bars        | `position = "stack"`                                                                                                                                       | `beside = FALSE`                                                       |
| Histograms          | [`geom_histogram()`](https://ggplot2.tidyverse.org/reference/geom_histogram.html)                                                                          | [`hist()`](https://rdrr.io/r/graphics/hist.html)                       |
| Scatter plots       | [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)                                                                                  | [`plot()`](https://rdrr.io/r/graphics/plot.default.html)               |
| Line plots          | [`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)                                                                                    | `plot(type = "l")`, [`lines()`](https://rdrr.io/r/graphics/lines.html) |
| Box plots           | [`geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)                                                                              | [`boxplot()`](https://rdrr.io/r/graphics/boxplot.html)                 |
| Heatmaps            | [`geom_tile()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)                                                                                    | [`image()`](https://rdrr.io/r/graphics/image.html)                     |
| Density/Smooth      | [`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html), [`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html) | `lines(density())`                                                     |

### Advanced Plot Types

| Plot Type           | ggplot2                                                                                                                                              | Base R                     |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------|
| Faceted plots       | [`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html), [`facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html) | `par(mfrow/mfcol)` + loops |
| Multi-panel layouts | `patchwork` package                                                                                                                                  | `par(mfrow)`, `par(mfcol)` |
| Multi-layered plots | Multiple `geom_*` layers                                                                                                                             | Sequential plot calls      |

See
[`vignette("plot-types")`](https://r.maidr.ai/articles/plot-types.md)
for detailed examples of each plot type.

## Accessibility features

- **Keyboard navigation** - explore data points using arrow keys
- **Screen reader support** - full ARIA labels and live announcements
- **Sonification** - hear data patterns through sound
- **Text descriptions** - automatic statistical summaries

## Getting help

- Report bugs or request features at [GitHub
  Issues](https://github.com/xability/r-maidr/issues)
- Read the documentation at the [package website](https://r.maidr.ai/)

## Learning more

- [`vignette("getting-started", package = "maidr")`](https://r.maidr.ai/articles/getting-started.md)
  for an introduction
- [`vignette("plot-types", package = "maidr")`](https://r.maidr.ai/articles/plot-types.md)
  for supported visualizations
- [`vignette("shiny-integration", package = "maidr")`](https://r.maidr.ai/articles/shiny-integration.md)
  for Shiny apps
