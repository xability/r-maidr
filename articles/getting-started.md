# Getting Started with MAIDR

## Introduction to MAIDR

**MAIDR** (Multimodal Access and Interactive Data Representation) is an
R package that makes data visualizations accessible to users with visual
impairments. It converts ggplot2 and Base R plots into interactive,
accessible formats with:

- **Keyboard navigation** - Explore data using arrow keys
- **Screen reader support** - Full ARIA labels and descriptions
- **Sonification** - Hear data patterns through sound
- **HTML/SVG output** - Standalone accessible visualizations

MAIDR helps data scientists and researchers create inclusive
visualizations that everyone can explore, regardless of visual ability.

## Installation

Install the development version from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("xability/r-maidr-prototype")
```

## Basic Workflow

MAIDR works with two main functions:

1.  **[`show()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/show.md)** -
    Display an interactive plot in RStudio Viewer or browser
2.  **[`save_html()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/save_html.md)** -
    Save a plot as a standalone HTML file

### Quick Example: ggplot2 Bar Chart

``` r
library(maidr)
library(ggplot2)

# Create sample data
sales_data <- data.frame(
  Product = c("A", "B", "C", "D"),
  Sales = c(150, 230, 180, 290)
)

# Create a bar chart
p <- ggplot(sales_data, aes(x = Product, y = Sales)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(
    title = "Product Sales by Category",
    x = "Product",
    y = "Sales Amount"
  ) +
  theme_minimal()

# Display interactively
show(p)

# Or save as HTML file
save_html(p, "sales_chart.html")
```

### Quick Example: Base R Plot

MAIDR also works with Base R plotting functions:

``` r
library(maidr)

# Create a simple barplot
categories <- c("A", "B", "C", "D")
values <- c(150, 230, 180, 290)

barplot(
  values,
  names.arg = categories,
  col = "steelblue",
  main = "Product Sales by Category",
  xlab = "Product",
  ylab = "Sales Amount"
)

# Note: For Base R plots, call show() with NO arguments
# after creating the plot
show()
```

## Exploring Accessible Plots

When you open a MAIDR plot, you can explore it using:

### Keyboard Navigation

- **Arrow keys** - Navigate between data points
- **Tab** - Move between interactive elements
- **Enter/Space** - Activate controls
- **Escape** - Exit modes

### Screen Reader Announcements

MAIDR plots include:

- Plot titles and descriptions
- Axis labels and ranges
- Data point values
- Navigation instructions

### Data Sonification

Plots can be heard through:

- Pitch mapping (higher values = higher pitch)
- Volume changes
- Different tones for different series

## Next Steps

- **[Supported Plot
  Types](http://xabilitylab.ischool.illinois.edu/r-maidr/articles/plot-types.md)** -
  See all available plot types
- **[Shiny
  Integration](http://xabilitylab.ischool.illinois.edu/r-maidr/articles/shiny-integration.md)** -
  Use MAIDR in Shiny apps
- **Package documentation** - Run
  [`?maidr::show`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/show.md)
  for function details

## Example Gallery

### Histogram

``` r
library(maidr)
library(ggplot2)

# Normal distribution
hist_data <- data.frame(values = rnorm(1000, mean = 100, sd = 15))

p <- ggplot(hist_data, aes(x = values)) +
  geom_histogram(bins = 30, fill = "skyblue", color = "black") +
  labs(
    title = "Distribution of Test Scores",
    x = "Score",
    y = "Frequency"
  ) +
  theme_minimal()

show(p)
```

### Scatter Plot

``` r
library(maidr)
library(ggplot2)

# Create sample data
scatter_data <- data.frame(
  height = rnorm(50, 170, 10),
  weight = rnorm(50, 70, 8),
  gender = sample(c("Male", "Female"), 50, replace = TRUE)
)

p <- ggplot(scatter_data, aes(x = height, y = weight, color = gender)) +
  geom_point(size = 3, alpha = 0.7) +
  labs(
    title = "Height vs Weight",
    x = "Height (cm)",
    y = "Weight (kg)"
  ) +
  theme_minimal()

show(p)
```

### Line Plot

``` r
library(maidr)
library(ggplot2)

# Time series data
months <- month.abb[1:12]
temperature <- c(5, 7, 12, 18, 22, 26, 28, 27, 23, 17, 11, 6)

temp_data <- data.frame(
  Month = factor(months, levels = months),
  Temperature = temperature
)

p <- ggplot(temp_data, aes(x = Month, y = Temperature, group = 1)) +
  geom_line(color = "red", linewidth = 1.5) +
  geom_point(color = "darkred", size = 3) +
  labs(
    title = "Average Monthly Temperature",
    x = "Month",
    y = "Temperature (°C)"
  ) +
  theme_minimal()

show(p)
```

## Tips for Creating Accessible Plots

1.  **Use clear titles** - Describe what the plot shows
2.  **Label axes properly** - Include units of measurement
3.  **Choose distinct colors** - Ensure good contrast
4.  **Add legends** - Explain what colors/shapes mean
5.  **Keep it simple** - Avoid overcrowded visualizations

## Getting Help

- Run
  [`?maidr::show`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/show.md)
  for function documentation
- Visit GitHub issues:
  [maidr/issues](https://github.com/xability/maidr/issues)
- Read the full documentation:
  [`help(package = "maidr")`](https://rdrr.io/pkg/maidr/man)

## Learn More

- **Accessibility standards**: [WCAG 2.1
  Guidelines](https://www.w3.org/WAI/WCAG22/quickref/?versions=2.1)
- **MAIDR website**: More examples and tutorials
- **Research papers**: Understanding multimodal data representation
