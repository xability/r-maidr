#!/usr/bin/env Rscript

# Example script for maidr package demonstrating all supported plot types
# This script generates interactive HTML files for various ggplot2 plot types

# Load required libraries
library(ggplot2)
library(devtools)

# Load the maidr package
# Use absolute path to ensure it works from anywhere
maidr_dir <- "/Users/niranjank/xability/r-maidr-prototype/maidr"
load_all(maidr_dir)

# Create output directory if it doesn't exist
output_dir <- "/Users/niranjank/xability/r-maidr-prototype/maidr/output"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("=== Maidr Package Examples - All Supported Plot Types ===\n")
cat("Output files will be saved to:", output_dir, "\n")

# Test 1: Simple bar plot
cat("\n=== TEST 1: Simple Bar Plot ===\n")
bar_data <- data.frame(
  Category = c("D", "B", "C", "A"),
  Value = c(10, 25, 15, 30)
)

p_bar <- ggplot(bar_data, aes(x = Category, y = Value)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "Simple Bar Test")

html_file_bar <- file.path(output_dir, "example_bar_plot.html")
result_bar <- show(p_bar, file = html_file_bar, open = FALSE)
cat("Bar plot:", if(file.exists(html_file_bar)) "✓" else "✗", "\n")

# Test 2: Dodged bar plot
cat("\n=== TEST 2: Dodged Bar Plot ===\n")
dodged_data <- data.frame(
  Category = rep(c("A", "B", "C"), each = 2),
  Type = rep(c("Type1", "Type2"), 3),
  Value = c(10, 15, 20, 25, 30, 35)
)

p_dodged <- ggplot(dodged_data, aes(x = Category, y = Value, fill = Type)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8)) +
  labs(title = "Dodged Bar Test")

html_file_dodged <- file.path(output_dir, "example_dodged_bar_plot.html")
result_dodged <- show(p_dodged, file = html_file_dodged, open = FALSE)
cat("Dodged bar plot:", if(file.exists(html_file_dodged)) "✓" else "✗", "\n")

# Test 3: Stacked bar plot
cat("\n=== TEST 3: Stacked Bar Plot ===\n")
stacked_data <- data.frame(
  Category = rep(c("A", "B", "C"), each = 2),
  Type = rep(c("Type1", "Type2"), 3),
  Value = c(10, 15, 20, 25, 30, 35)
)

p_stacked <- ggplot(stacked_data, aes(x = Category, y = Value, fill = Type)) +
  geom_bar(stat = "identity", position = position_stack()) +
  labs(title = "Stacked Bar Test")

html_file_stacked <- file.path(output_dir, "example_stacked_bar_plot.html")
result_stacked <- show(p_stacked, file = html_file_stacked, open = FALSE)
cat("Stacked bar plot:", if(file.exists(html_file_stacked)) "✓" else "✗", "\n")

# Test 4: Histogram
cat("\n=== TEST 4: Histogram ===\n")
hist_data <- data.frame(
  values = rnorm(100, mean = 0, sd = 1)
)

p_hist <- ggplot(hist_data, aes(x = values)) +
  geom_histogram(bins = 20, fill = "steelblue", color = "black") +
  labs(title = "Histogram Test")

html_file_hist <- file.path(output_dir, "example_histogram.html")
result_hist <- show(p_hist, file = html_file_hist, open = FALSE)
cat("Histogram:", if(file.exists(html_file_hist)) "✓" else "✗", "\n")

# Test 5: Smooth plot
cat("\n=== TEST 5: Smooth Plot ===\n")
smooth_data <- data.frame(
  x = rnorm(100, mean = 0, sd = 1)
)

p_smooth <- ggplot(smooth_data, aes(x = x)) +
  geom_density(fill = "lightblue", alpha = 0.5) +
  labs(title = "Smooth Plot Test")

html_file_smooth <- file.path(output_dir, "example_smooth_plot.html")
result_smooth <- show(p_smooth, file = html_file_smooth, open = FALSE)
cat("Smooth plot:", if(file.exists(html_file_smooth)) "✓" else "✗", "\n")

# Test 6: Single Line plot
cat("\n=== TEST 6: Single Line Plot ===\n")
line_data <- data.frame(
  x = 1:10,
  y = c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
)

p_line <- ggplot(line_data, aes(x = x, y = y)) +
  geom_line(color = "steelblue", linewidth = 1.5) +
  labs(title = "Single Line Plot Test", x = "X values", y = "Y values") +
  theme_minimal()

html_file_line <- file.path(output_dir, "example_line_plot.html")
result_line <- show(p_line, file = html_file_line, open = FALSE)
cat("Single line plot:", if(file.exists(html_file_line)) "✓" else "✗", "\n")

# Test 7: Multiline plot (3 series with 10 points each)
cat("\n=== TEST 7: Multiline Plot (3 Series with 10 Points) ===\n")
# Create data with 10 points for each of 3 series
set.seed(123)  # For reproducible data
x <- 1:10
y1 <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
y2 <- c(1, 3, 5, 2, 4, 6, 8, 7, 5, 3)
y3 <- c(3, 1, 4, 6, 5, 2, 4, 5, 7, 6)

multiline_data <- data.frame(
  x = rep(x, 3),
  y = c(y1, y2, y3),
  series = rep(c("G 1", "G 2", "G 3"), each = length(x))
)

p_multiline <- ggplot(multiline_data, aes(x = x, y = y, color = series)) +
  geom_line(linewidth = 1) +
  labs(
    title = "Multiline Plot Test (3 Series with 10 Points)",
    x = "X values", 
    y = "Y values",
    color = "Series"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

html_file_multiline <- file.path(output_dir, "example_multiline_plot.html")
result_multiline <- show(p_multiline, file = html_file_multiline, open = FALSE)
cat("Multiline plot (3 series with 10 points):", if(file.exists(html_file_multiline)) "✓" else "✗", "\n")

# Test 8: Histogram with Density Curve (Iris Dataset)
cat("\n=== TEST 8: Histogram with Density Curve ===\n")

# Create sample data equivalent to iris petal lengths
set.seed(123)
petal_lengths <- rnorm(150, mean = 3.8, sd = 1.8)  # Approximate iris petal length distribution
petal_data <- data.frame(petal_length = petal_lengths)

# Create histogram with density curve (equivalent to seaborn histplot with kde=True)
p_hist_density <- ggplot(petal_data, aes(x = petal_length)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 0.5, fill = "lightblue", alpha = 0.7, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(
    title = "Petal Lengths in Iris Dataset",
    x = "Petal Length (cm)",
    y = "Density"
  ) +
  theme_minimal()

html_file_hist_density <- file.path(output_dir, "example_histogram_density.html")
result_hist_density <- show(p_hist_density, file = html_file_hist_density, open = FALSE)
cat("Histogram with density curve:", if(file.exists(html_file_hist_density)) "✓" else "✗", "\n")

# Test 9: Heatmap with labels
cat("\n=== TEST 9: Heatmap with Labels ===\n")
heatmap_data <- data.frame(
  x = c("B", "A", "B", "A"),
  y = c("2", "2", "1", "1"),
  z = c(4, 3, 2, 1)
)

p_heatmap_labels <- ggplot(heatmap_data, aes(x = x, y = y, fill = z)) + 
  geom_tile() +
  geom_text(aes(label = z), color = "white", size = 4) +
  labs(title = "Heatmap with Labels Test")

html_file_heatmap_labels <- file.path(output_dir, "example_heatmap_with_labels.html")
result_heatmap_labels <- show(p_heatmap_labels, file = html_file_heatmap_labels, open = FALSE)
cat("Heatmap with labels:", if(file.exists(html_file_heatmap_labels)) "✓" else "✗", "\n")

# Test 10: Point/Scatter plot with multiple y values per x
cat("\n=== TEST 10: Point/Scatter Plot with Multiple Y Values per X ===\n")
# Create data with multiple y values for single x value
set.seed(123)
x_values <- rep(1:5, each = 3)  # 3 measurements per x value
y_values <- c(rnorm(3, 10, 1), rnorm(3, 15, 2), rnorm(3, 12, 1.5),
              rnorm(3, 18, 1.8), rnorm(3, 14, 0.8))
groups <- rep(c("A", "B", "C"), times = 5)

point_data <- data.frame(
  x = x_values,
  y = y_values,
  group = groups
)

# Create the scatter plot with multiple y values per x
p_point <- ggplot(point_data, aes(x = x, y = y, color = group)) +
  geom_point(size = 4, alpha = 0.8) +
  labs(
    title = "Multiple Y Values per X Value",
    x = "X Values",
    y = "Y Values",
    color = "Group"
  ) +
  theme_minimal() +
  scale_x_continuous(breaks = 1:5)

html_file_point <- file.path(output_dir, "example_point_plot.html")
result_point <- show(p_point, file = html_file_point, open = FALSE)
cat("Point/Scatter plot (multiple y per x):", if(file.exists(html_file_point)) "✓" else "✗", "\n")

# Test 11: Dual-axis plot (Bar + Line)
cat("\n=== TEST 11: Dual-Axis Plot (Bar + Line) ===\n")
# Generate sample data (equivalent to the Python version)
x_dual <- 0:4
bar_data_dual <- c(3, 5, 2, 7, 3)
line_data_dual <- c(10, 8, 12, 14, 9)

# Create data frame
dual_plot_data <- data.frame(
  x = x_dual,
  bar_values = bar_data_dual,
  line_values = line_data_dual
)

# Create the dual-axis plot
p_dual_axis <- ggplot(dual_plot_data, aes(x = x)) +
  # Bar chart on primary y-axis
  geom_bar(aes(y = bar_values), stat = "identity", fill = "skyblue", alpha = 0.7) +
  # Line chart on secondary y-axis (scaled)
  geom_line(aes(y = line_values * max(bar_data_dual) / max(line_data_dual)), color = "red", linewidth = 1) +

  # Labels and title
  labs(
    title = "Dual-Axis Plot Example",
    x = "X values",
    y = "Bar values"
  ) +

  # Scale the secondary axis
  scale_y_continuous(
    name = "Bar values",
    sec.axis = sec_axis(~ . * max(line_data_dual) / max(bar_data_dual), name = "Line values")
  ) +

  # Theme
  theme_minimal() +
  theme(
    axis.title.y.right = element_text(color = "red"),
    axis.text.y.right = element_text(color = "red"),
    axis.title.y.left = element_text(color = "blue"),
    axis.text.y.left = element_text(color = "blue")
  )

html_file_dual_axis <- file.path(output_dir, "example_dual_axis_plot.html")
result_dual_axis <- show(p_dual_axis, file = html_file_dual_axis, open = FALSE)
cat("Dual-axis plot (bar + line):", if(file.exists(html_file_dual_axis)) "✓" else "✗", "\n")

# Summary
cat("\n=== TEST 12: Boxplot (Horizontal) ===\n")

# Use iris dataset for boxplot example
iris_data <- datasets::iris

p_box <- ggplot(iris_data, aes(x = Petal.Length, y = Species)) +
  geom_boxplot(fill = "lightblue", color = "darkblue", alpha = 0.7) +
  labs(
    title = "Petal Length by Species from Iris Dataset",
    x = "Petal Length",
    y = "Species"
  ) +
  theme_minimal()

html_file_box <- file.path(output_dir, "example_boxplot_horizontal.html")
result_box <- show(p_box, file = html_file_box, open = FALSE)
cat("Boxplot (horizontal):", if(file.exists(html_file_box)) "✓" else "✗", "\n")

# Test 13: Faceted Bar Plot
cat("\n=== TEST 13: Faceted Bar Plot ===\n")
# Create example data for faceted bar plot
set.seed(42)
facet_bar_data <- data.frame(
  x = rep(1:5, 4),
  y = c(
    runif(5, 1, 10),
    runif(5, 10, 100),
    runif(5, 1, 36),
    runif(5, 1, 42)
  ),
  group = rep(c('Group 1', 'Group 2', 'Group 3', 'Group 4'), each = 5)
)

p_facet_bar <- ggplot(facet_bar_data, aes(x = x, y = y)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  facet_wrap(~ group, ncol = 2) +
  labs(
    title = "Faceted Bar Plot Test",
    x = "Categories",
    y = "Values"
  ) +
  theme_minimal()

html_file_facet_bar <- file.path(output_dir, "example_facet_bar_plot.html")
result_facet_bar <- show(p_facet_bar, file = html_file_facet_bar, open = FALSE)
cat("Faceted bar plot:", if(file.exists(html_file_facet_bar)) "✓" else "✗", "\n")

# Test 14: Faceted Point Plot
cat("\n=== TEST 14: Faceted Point Plot ===\n")
# Create example data for faceted point plot
set.seed(42)
facet_point_data <- data.frame(
  x = rep(1:5, 4),
  y = c(
    runif(5, 1, 10),
    runif(5, 10, 100),
    runif(5, 1, 36),
    runif(5, 1, 42)
  ),
  group = rep(c('Group 1', 'Group 2', 'Group 3', 'Group 4'), each = 5)
)

p_facet_point <- ggplot(facet_point_data, aes(x = x, y = y)) +
  geom_point(size = 3, color = "steelblue") +
  facet_wrap(~ group, ncol = 2) +
  labs(
    title = "Faceted Point Plot Test",
    x = "X Values",
    y = "Y Values"
  ) +
  theme_minimal()

html_file_facet_point <- file.path(output_dir, "example_facet_point_plot.html")
result_facet_point <- show(p_facet_point, file = html_file_facet_point, open = FALSE)
cat("Faceted point plot:", if(file.exists(html_file_facet_point)) "✓" else "✗", "\n")

# Test 15: Faceted Line Plot
cat("\n=== TEST 15: Faceted Line Plot ===\n")
# Create example data for faceted line plot
set.seed(42)
facet_line_data <- data.frame(
  x = rep(1:5, 4),
  y = c(
    runif(5, 1, 10),
    runif(5, 10, 100),
    runif(5, 1, 36),
    runif(5, 1, 42)
  ),
  group = rep(c('Group 1', 'Group 2', 'Group 3', 'Group 4'), each = 5)
)

p_facet_line <- ggplot(facet_line_data, aes(x = x, y = y)) +
  geom_line(color = "steelblue", linewidth = 1.5) +
  facet_wrap(~ group, ncol = 2) +
  labs(
    title = "Faceted Line Plot Test",
    x = "X Values",
    y = "Y Values"
  ) +
  theme_minimal()

html_file_facet_line <- file.path(output_dir, "example_facet_line_plot.html")
result_facet_line <- show(p_facet_line, file = html_file_facet_line, open = FALSE)
cat("Faceted line plot:", if(file.exists(html_file_facet_line)) "✓" else "✗", "\n")

cat("\n=== SUMMARY ===\n")
cat("Generated HTML files in output/ directory:\n")
cat("- Bar plot:", if(file.exists(html_file_bar)) "✓" else "✗", "\n")
cat("- Dodged bar plot:", if(file.exists(html_file_dodged)) "✓" else "✗", "\n")
cat("- Stacked bar plot:", if(file.exists(html_file_stacked)) "✓" else "✗", "\n")
cat("- Histogram:", if(file.exists(html_file_hist)) "✓" else "✗", "\n")
cat("- Smooth plot:", if(file.exists(html_file_smooth)) "✓" else "✗", "\n")
cat("- Single line plot:", if(file.exists(html_file_line)) "✓" else "✗", "\n")
cat("- Multiline plot (3 series with 10 points):", if(file.exists(html_file_multiline)) "✓" else "✗", "\n")
cat("- Histogram with density curve:", if(file.exists(html_file_hist_density)) "✓" else "✗", "\n")
cat("- Heatmap with labels:", if(file.exists(html_file_heatmap_labels)) "✓" else "✗", "\n")
cat("- Point/Scatter plot (multiple y per x):", if(file.exists(html_file_point)) "✓" else "✗", "\n")
cat("- Dual-axis plot (bar + line):", if(file.exists(html_file_dual_axis)) "✓" else "✗", "\n")
cat("- Boxplot (horizontal):", if(file.exists(html_file_box)) "✓" else "✗", "\n")
cat("- Faceted bar plot:", if(file.exists(html_file_facet_bar)) "✓" else "✗", "\n")
cat("- Faceted point plot:", if(file.exists(html_file_facet_point)) "✓" else "✗", "\n")
cat("- Faceted line plot:", if(file.exists(html_file_facet_line)) "✓" else "✗", "\n")

cat("\nAll examples completed successfully!\n")
cat("Check the output/ directory for interactive HTML files.\n") 