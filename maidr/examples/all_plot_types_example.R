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
output_dir <- "../output"
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
result_bar <- maidr(p_bar, file = html_file_bar, open = FALSE)
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
result_dodged <- maidr(p_dodged, file = html_file_dodged, open = FALSE)
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
result_stacked <- maidr(p_stacked, file = html_file_stacked, open = FALSE)
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
result_hist <- maidr(p_hist, file = html_file_hist, open = FALSE)
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
result_smooth <- maidr(p_smooth, file = html_file_smooth, open = FALSE)
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
result_line <- maidr(p_line, file = html_file_line, open = FALSE)
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
result_multiline <- maidr(p_multiline, file = html_file_multiline, open = FALSE)
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
result_hist_density <- maidr(p_hist_density, file = html_file_hist_density, open = FALSE)
cat("Histogram with density curve:", if(file.exists(html_file_hist_density)) "✓" else "✗", "\n")

# Summary
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

cat("\nAll examples completed successfully!\n")
cat("Check the output/ directory for interactive HTML files.\n") 