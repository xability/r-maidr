# Supported Plot Types in MAIDR

## Overview

MAIDR supports a comprehensive range of plot types from both **ggplot2**
and **Base R**. This vignette demonstrates each supported visualization
with example code.

## Bar Charts

### Simple Bar Chart

``` r
library(maidr)
library(ggplot2)

# ggplot2
bar_data <- data.frame(
  Category = c("A", "B", "C", "D"),
  Value = c(30, 25, 35, 20)
)

p <- ggplot(bar_data, aes(x = Category, y = Value)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "Simple Bar Chart") +
  theme_minimal()

show(p)

# Base R equivalent
barplot(bar_data$Value,
  names.arg = bar_data$Category,
  col = "steelblue",
  main = "Simple Bar Chart"
)
show() # Note: No arguments for Base R plots
```

### Dodged Bar Chart

``` r
library(maidr)
library(ggplot2)

# ggplot2
dodged_data <- data.frame(
  Category = rep(c("A", "B", "C"), each = 2),
  Type = rep(c("Type1", "Type2"), 3),
  Value = c(10, 15, 20, 25, 30, 35)
)

p <- ggplot(dodged_data, aes(x = Category, y = Value, fill = Type)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8)) +
  labs(title = "Dodged Bar Chart") +
  theme_minimal()

show(p)

# Base R equivalent
matrix_data <- matrix(c(10, 15, 20, 25, 30, 35), nrow = 2)
barplot(matrix_data,
  beside = TRUE, # Creates dodged effect
  names.arg = c("A", "B", "C"),
  col = c("steelblue", "coral"),
  legend = c("Type1", "Type2"),
  main = "Dodged Bar Chart"
)
show()
```

### Stacked Bar Chart

``` r
library(maidr)
library(ggplot2)

# ggplot2
stacked_data <- data.frame(
  Category = rep(c("A", "B", "C"), each = 2),
  Type = rep(c("Type1", "Type2"), 3),
  Value = c(10, 15, 20, 25, 30, 35)
)

p <- ggplot(stacked_data, aes(x = Category, y = Value, fill = Type)) +
  geom_bar(stat = "identity", position = position_stack()) +
  labs(title = "Stacked Bar Chart") +
  theme_minimal()

show(p)

# Base R equivalent
matrix_data <- matrix(c(10, 15, 20, 25, 30, 35), nrow = 2)
barplot(matrix_data,
  beside = FALSE, # Creates stacked effect
  names.arg = c("A", "B", "C"),
  col = c("steelblue", "coral"),
  legend = c("Type1", "Type2"),
  main = "Stacked Bar Chart"
)
show()
```

## Histograms

``` r
library(maidr)
library(ggplot2)

# ggplot2
hist_data <- data.frame(values = rnorm(1000, mean = 0, sd = 1))

p <- ggplot(hist_data, aes(x = values)) +
  geom_histogram(bins = 30, fill = "skyblue", color = "black") +
  labs(title = "Histogram", x = "Values", y = "Frequency") +
  theme_minimal()

show(p)

# Base R equivalent
hist(rnorm(1000, mean = 0, sd = 1),
  breaks = 30,
  col = "skyblue",
  border = "black",
  main = "Histogram",
  xlab = "Values",
  ylab = "Frequency"
)
show()
```

## Scatter/Point Plots

``` r
library(maidr)
library(ggplot2)

# ggplot2
scatter_data <- data.frame(
  x = rnorm(50),
  y = rnorm(50),
  group = sample(c("A", "B", "C"), 50, replace = TRUE)
)

p <- ggplot(scatter_data, aes(x = x, y = y, color = group)) +
  geom_point(size = 3, alpha = 0.7) +
  labs(title = "Scatter Plot") +
  theme_minimal()

show(p)

# Base R equivalent
x <- rnorm(50)
y <- rnorm(50)
plot(x, y,
  pch = 19,
  col = rainbow(3)[as.numeric(factor(sample(c("A", "B", "C"), 50, replace = TRUE)))],
  main = "Scatter Plot"
)
show()
```

## Line Plots

### Single Line

``` r
library(maidr)
library(ggplot2)

# ggplot2
line_data <- data.frame(
  x = 1:10,
  y = c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
)

p <- ggplot(line_data, aes(x = x, y = y)) +
  geom_line(color = "steelblue", linewidth = 1.5) +
  labs(title = "Single Line Plot") +
  theme_minimal()

show(p)

# Base R equivalent
x <- 1:10
y <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
plot(x, y, type = "l", col = "steelblue", lwd = 2, main = "Single Line Plot")
show()
```

### Multiple Lines

``` r
library(maidr)
library(ggplot2)

# ggplot2
multiline_data <- data.frame(
  x = rep(1:10, 3),
  y = c(
    c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4), # Series 1
    c(1, 3, 5, 2, 4, 6, 8, 7, 5, 3), # Series 2
    c(3, 1, 4, 6, 5, 2, 4, 5, 7, 6) # Series 3
  ),
  series = rep(c("A", "B", "C"), each = 10)
)

p <- ggplot(multiline_data, aes(x = x, y = y, color = series)) +
  geom_line(linewidth = 1) +
  labs(title = "Multiline Plot") +
  theme_minimal()

show(p)

# Base R equivalent
x <- 1:10
y1 <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
y2 <- c(1, 3, 5, 2, 4, 6, 8, 7, 5, 3)
y3 <- c(3, 1, 4, 6, 5, 2, 4, 5, 7, 6)

plot(x, y1, type = "l", col = "red", lwd = 2, main = "Multiline Plot", ylim = c(0, 10))
lines(x, y2, col = "blue", lwd = 2)
lines(x, y3, col = "green", lwd = 2)
show()
```

## Box Plots

``` r
library(maidr)
library(ggplot2)

# ggplot2 - Horizontal
p <- ggplot(iris, aes(x = Petal.Length, y = Species)) +
  geom_boxplot(fill = "lightblue", alpha = 0.7) +
  labs(title = "Boxplot - Petal Length by Species") +
  theme_minimal()

show(p)

# ggplot2 - Vertical
p_vert <- ggplot(iris, aes(x = Species, y = Petal.Length)) +
  geom_boxplot(fill = "lightblue", alpha = 0.7) +
  labs(title = "Boxplot - Vertical Orientation") +
  theme_minimal()

show(p_vert)

# Base R equivalent
boxplot(Petal.Length ~ Species,
  data = iris,
  col = "lightblue",
  main = "Boxplot - Petal Length by Species",
  horizontal = TRUE
)
show()
```

## Heatmaps

``` r
library(maidr)
library(ggplot2)

# ggplot2
heatmap_data <- data.frame(
  x = rep(c("A", "B"), each = 2),
  y = rep(c("1", "2"), 2),
  z = c(1, 2, 3, 4)
)

p <- ggplot(heatmap_data, aes(x = x, y = y, fill = z)) +
  geom_tile() +
  geom_text(aes(label = z), color = "white", size = 5) +
  labs(title = "Heatmap with Labels") +
  theme_minimal()

show(p)

# Base R equivalent
matrix_data <- matrix(c(1, 2, 3, 4), nrow = 2)
image(matrix_data,
  col = heat.colors(10),
  main = "Heatmap",
  axes = FALSE
)
axis(1, at = seq(0, 1, length.out = 2), labels = c("A", "B"))
axis(2, at = seq(0, 1, length.out = 2), labels = c("1", "2"))
show()
```

## Density/Smooth Plots

``` r
library(maidr)
library(ggplot2)

# ggplot2
density_data <- data.frame(values = rnorm(1000, mean = 0, sd = 1))

p <- ggplot(density_data, aes(x = values)) +
  geom_density(fill = "lightblue", alpha = 0.5) +
  labs(title = "Density Plot") +
  theme_minimal()

show(p)

# Base R equivalent
values <- rnorm(1000, mean = 0, sd = 1)
plot(density(values),
  col = "blue",
  lwd = 2,
  main = "Density Plot"
)
polygon(density(values), col = rgb(0.678, 0.847, 0.902, 0.5))
show()
```

## Faceted Plots

``` r
library(maidr)
library(ggplot2)

# ggplot2 - Faceted bar plot
facet_data <- data.frame(
  x = rep(1:5, 4),
  y = runif(20, 1, 100),
  group = rep(c("Group 1", "Group 2", "Group 3", "Group 4"), each = 5)
)

p <- ggplot(facet_data, aes(x = x, y = y)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  facet_wrap(~group, ncol = 2) +
  labs(title = "Faceted Bar Plot") +
  theme_minimal()

show(p)

# ggplot2 - facet_grid example
p_grid <- ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point() +
  facet_grid(cyl ~ gear) +
  labs(title = "Facet Grid: Cylinders vs Gears") +
  theme_minimal()

show(p_grid)
```

## Multi-Panel Layouts

### ggplot2 with Patchwork

``` r
library(maidr)
library(ggplot2)
library(patchwork)

# Create individual plots
p1 <- ggplot(data.frame(x = 1:10, y = rnorm(10)), aes(x, y)) +
  geom_line(color = "steelblue") +
  labs(title = "Line Plot") +
  theme_minimal()

p2 <- ggplot(data.frame(x = c("A", "B", "C"), y = c(10, 20, 15)), aes(x, y)) +
  geom_bar(stat = "identity", fill = "coral") +
  labs(title = "Bar Plot") +
  theme_minimal()

# Combine with patchwork (side by side)
combined <- p1 + p2
show(combined)

# 2x2 layout
p3 <- ggplot(mtcars, aes(x = mpg)) +
  geom_histogram(fill = "lightgreen", bins = 10) +
  theme_minimal()

p4 <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_boxplot(fill = "lavender") +
  theme_minimal()

combined_2x2 <- (p1 + p2) / (p3 + p4)
show(combined_2x2)
```

### Base R with par(mfrow/mfcol)

``` r
library(maidr)

# 2x2 multi-panel layout using par(mfrow)
par(mfrow = c(2, 2))

# Panel 1: Bar plot
barplot(c(10, 20, 15, 25),
  names.arg = c("A", "B", "C", "D"),
  col = "steelblue", main = "Bar Plot"
)

# Panel 2: Histogram
hist(rnorm(100), col = "coral", main = "Histogram")

# Panel 3: Scatter plot
plot(mtcars$wt, mtcars$mpg,
  pch = 19, col = "darkgreen",
  main = "Scatter Plot", xlab = "Weight", ylab = "MPG"
)

# Panel 4: Line plot
x <- 1:10
y <- cumsum(rnorm(10))
plot(x, y, type = "l", col = "purple", lwd = 2, main = "Line Plot")

show()

# Reset to single panel
par(mfrow = c(1, 1))
```

## Multi-Layered Plots

Multi-layered plots combine multiple visualization types in a single
plot.

### ggplot2 Multi-Layer Examples

``` r
library(maidr)
library(ggplot2)

# Histogram with density overlay
p_hist_density <- ggplot(mtcars, aes(x = mpg)) +
  geom_histogram(aes(y = after_stat(density)),
    bins = 15,
    fill = "lightblue", color = "white"
  ) +
  geom_density(color = "red", linewidth = 1.2) +
  labs(title = "Histogram with Density Curve") +
  theme_minimal()

show(p_hist_density)

# Scatter plot with smooth line
p_scatter_smooth <- ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(color = "steelblue", size = 3) +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(title = "Scatter Plot with Linear Regression") +
  theme_minimal()

show(p_scatter_smooth)

# Bar plot with line overlay
combo_data <- data.frame(
  month = month.abb[1:6],
  sales = c(100, 120, 90, 150, 130, 160),
  target = c(110, 110, 110, 140, 140, 140)
)

p_bar_line <- ggplot(combo_data, aes(x = month)) +
  geom_bar(aes(y = sales), stat = "identity", fill = "steelblue", alpha = 0.7) +
  geom_line(aes(y = target, group = 1), color = "red", linewidth = 1.5) +
  geom_point(aes(y = target), color = "red", size = 3) +
  labs(title = "Sales vs Target", y = "Value") +
  theme_minimal()

show(p_bar_line)
```

### Base R Multi-Layer Examples

``` r
library(maidr)

# Histogram with density curve
hist(mtcars$mpg,
  breaks = 15, freq = FALSE,
  col = "lightblue", border = "white",
  main = "Histogram with Density Curve",
  xlab = "Miles per Gallon"
)
lines(density(mtcars$mpg), col = "red", lwd = 2)
show()

# Scatter plot with regression line
plot(mtcars$wt, mtcars$mpg,
  pch = 19, col = "steelblue",
  main = "Scatter Plot with Regression Line",
  xlab = "Weight", ylab = "MPG"
)
abline(lm(mpg ~ wt, data = mtcars), col = "red", lwd = 2)
show()

# Scatter plot with LOESS smooth
plot(mtcars$wt, mtcars$mpg,
  pch = 19, col = "darkgreen",
  main = "Scatter Plot with LOESS Smooth",
  xlab = "Weight", ylab = "MPG"
)
loess_fit <- loess(mpg ~ wt, data = mtcars)
wt_seq <- seq(min(mtcars$wt), max(mtcars$wt), length.out = 100)
lines(wt_seq, predict(loess_fit, data.frame(wt = wt_seq)),
  col = "red", lwd = 2
)
show()
```

## When to Use Each Plot Type

| Plot Type         | Best For                        | Example Use Case            |
|-------------------|---------------------------------|-----------------------------|
| **Bar Chart**     | Comparing categories            | Sales by product            |
| **Histogram**     | Showing distributions           | Test score frequencies      |
| **Scatter Plot**  | Relationships between variables | Height vs weight            |
| **Line Plot**     | Trends over time/order          | Stock prices                |
| **Box Plot**      | Distribution comparison         | Salary by department        |
| **Heatmap**       | Matrix relationships            | Correlation matrices        |
| **Density**       | Smooth distributions            | Probability density         |
| **Faceted**       | Comparing subgroups             | Regional sales trends       |
| **Multi-Panel**   | Multiple related views          | Dashboard layouts           |
| **Multi-Layered** | Combining visualizations        | Histogram + density overlay |

## Next Steps

- **[Getting
  Started](https://r.maidr.ai/articles/getting-started.md)** - Learn the
  basics
- **[Shiny
  Integration](https://r.maidr.ai/articles/shiny-integration.md)** - Use
  in interactive apps
- **Package documentation** - Run
  [`help(package = "maidr")`](https://r.maidr.ai/reference)
