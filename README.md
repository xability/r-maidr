# r-maidr: Making ggplot2 Plots Accessible

An R package that extracts data from ggplot2 plots to make them accessible via JavaScript backend, similar to py-maidr for matplotlib/seaborn.

## Installation

```r
# Install from CRAN (when published)
install.packages("r-maidr")

# Or install from GitHub
devtools::install_github("yourusername/r-maidr")
```

## Quick Start

```r
library(r-maidr)
library(ggplot2)

# Create a ggplot2 plot
p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  stat_summary(geom = "bar", fun = mean, fill = "steelblue") +
  labs(title = "Average MPG by Cylinders", x = "Cylinders", y = "MPG")

# Display accessible version in browser (like py-maidr's maidr.show())
maidr.show(p)
```

## Usage Examples

### Basic Usage
```r
# Create any ggplot2 plot
p <- ggplot(iris, aes(x = Species, y = Sepal.Length)) +
  stat_summary(geom = "bar", fun = mean, fill = "coral")

# Show accessible version
maidr.show(p)
```

### Save to File
```r
# Save accessible plot to specific file
maidr.show(p, output_file = "my_plot.html", open_browser = FALSE)
```

### Extract Data Only
```r
# Get structured data without creating HTML
maidr_data <- extract_maidr_data(p)
print(maidr_data$plot_df)
```

## Features

- **Accessible Visualizations**: Creates interactive HTML plots with accessibility features
- **Modular Design**: Easy to extend for new plot types
- **py-maidr Compatible**: Similar API to the Python version
- **ggplot2 Integration**: Works seamlessly with ggplot2 plots
- **Automatic Setup**: No manual registration needed

## Supported Plot Types

Currently supports:
- Bar plots (`geom_bar`, `geom_col`)

## Architecture

The package uses a modular architecture with:
- **Extractors**: Individual files for each plot type (`R/extractors/`)
- **Registry**: Maps ggplot2 geoms to extractors (`R/registry.R`)
- **Utils**: General utility functions (`R/utils.R`)
- **Main Package**: Orchestration functions (`R/maidr.R`)

## Development

For development and testing:
```r
# Load package files directly
source("R/utils.R")
source("R/extractors/extract_bar.R")
source("R/registry.R")
source("R/maidr.R")

# Test functionality
maidr.show(your_ggplot)
```

## License

MIT License 