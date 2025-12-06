# maidr

## Overview

maidr (Multimodal Access and Interactive Data Representation) makes data
visualizations accessible to users with visual impairments. It converts
ggplot2 and Base R plots into interactive, accessible HTML/SVG formats
with keyboard navigation, screen reader support, and sonification.

The package provides two main functions:

- [`show()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/show.md)
  displays an interactive accessible plot in RStudio Viewer or browser
- [`save_html()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/save_html.md)
  exports a plot as a standalone HTML file

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

maidr supports common visualization types in both ggplot2 and Base R:

- Bar charts (simple, grouped, stacked)
- Histograms
- Scatter plots
- Line plots
- Box plots
- Heatmaps

## Accessibility features

- **Keyboard navigation** - explore data points using arrow keys
- **Screen reader support** - full ARIA labels and live announcements
- **Sonification** - hear data patterns through sound
- **Text descriptions** - automatic statistical summaries

## Getting help

- Report bugs or request features at [GitHub
  Issues](https://github.com/xability/r-maidr/issues)
- Read the documentation at the [package
  website](http://xabilitylab.ischool.illinois.edu/r-maidr/)

## Learning more

- [`vignette("getting-started", package = "maidr")`](http://xabilitylab.ischool.illinois.edu/r-maidr/articles/getting-started.md)
  for an introduction
- [`vignette("plot-types", package = "maidr")`](http://xabilitylab.ischool.illinois.edu/r-maidr/articles/plot-types.md)
  for supported visualizations
- [`vignette("shiny-integration", package = "maidr")`](http://xabilitylab.ischool.illinois.edu/r-maidr/articles/shiny-integration.md)
  for Shiny apps
