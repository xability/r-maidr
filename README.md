# maidr <img src="man/figures/logo.svg" align="right" height="139" alt="maidr logo" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/xability/r-maidr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/xability/r-maidr/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

## Overview

maidr (Multimodal Access and Interactive Data Representation) makes data visualizations accessible to users with visual impairments. It converts ggplot2 and Base R plots into interactive, accessible HTML/SVG formats with keyboard navigation, screen reader support, and sonification.

The package provides two main functions:

- `show()` displays an interactive accessible plot in RStudio Viewer or browser
- `save_html()` exports a plot as a standalone HTML file

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

maidr supports a wide range of visualization types in both ggplot2 and Base R:

### Basic Plot Types
| Plot Type | ggplot2 | Base R |
|-----------|---------|--------|
| Bar charts | `geom_bar()`, `geom_col()` | `barplot()` |
| Grouped/Dodged bars | `position = "dodge"` | `beside = TRUE` |
| Stacked bars | `position = "stack"` | `beside = FALSE` |
| Histograms | `geom_histogram()` | `hist()` |
| Scatter plots | `geom_point()` | `plot()` |
| Line plots | `geom_line()` | `plot(type = "l")`, `lines()` |
| Box plots | `geom_boxplot()` | `boxplot()` |
| Heatmaps | `geom_tile()` | `image()` |
| Density/Smooth | `geom_smooth()`, `geom_density()` | `lines(density())` |

### Advanced Plot Types
| Plot Type | ggplot2 | Base R |
|-----------|---------|--------|
| Faceted plots | `facet_wrap()`, `facet_grid()` | `par(mfrow/mfcol)` + loops |
| Multi-panel layouts | `patchwork` package | `par(mfrow)`, `par(mfcol)` |
| Multi-layered plots | Multiple `geom_*` layers | Sequential plot calls |

See `vignette("plot-types")` for detailed examples of each plot type.

## Accessibility features

- **Keyboard navigation** - explore data points using arrow keys
- **Screen reader support** - full ARIA labels and live announcements
- **Sonification** - hear data patterns through sound
- **Text descriptions** - automatic statistical summaries

## Getting help

- Report bugs or request features at [GitHub Issues](https://github.com/xability/r-maidr/issues)
- Read the documentation at the [package website](http://xabilitylab.ischool.illinois.edu/r-maidr/)

## Learning more
- `vignette("getting-started", package = "maidr")` for an introduction
- `vignette("plot-types", package = "maidr")` for supported visualizations
- `vignette("shiny-integration", package = "maidr")` for Shiny apps
