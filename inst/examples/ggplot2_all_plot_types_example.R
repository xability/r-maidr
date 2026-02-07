#!/usr/bin/env Rscript

# Example script for maidr package demonstrating all supported plot types
# This script generates interactive HTML files for various ggplot2 plot types
# Includes examples of axis value formatting using maidr label functions

# Load required libraries
library(ggplot2)
library(devtools)
library(patchwork)

# Load the maidr package
# Get the directory where this script is located
script_path <- commandArgs(trailingOnly = FALSE)
script_file <- sub("--file=", "", script_path[grep("--file=", script_path)])
script_dir <- dirname(normalizePath(script_file))
# Script is in inst/examples/, so go up two levels to reach package root
maidr_dir <- dirname(dirname(script_dir))
load_all(maidr_dir)

# Create output directory inside inst/ if it doesn't exist
# script_dir is inst/examples, so go up one level to inst/
output_dir <- file.path(dirname(script_dir), "output")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("=== Maidr Package Examples - All Supported Plot Types ===\n")
cat("Output files will be saved to:", output_dir, "\n")

# Test 1: Simple bar plot with CURRENCY formatting
cat("\n=== TEST 1: Simple Bar Plot (Currency Formatting) ===\n")
bar_data <- data.frame(
  Category = c("Product A", "Product B", "Product C", "Product D"),
  Revenue = c(1500.50, 2500.75, 1850.25, 3200.00)
)

p_bar <- ggplot(bar_data, aes(x = Category, y = Revenue)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  scale_y_continuous(labels = scales::label_dollar(accuracy = 0.01)) +
  labs(title = "Product Revenue", x = "Product", y = "Revenue (USD)")

html_file_bar <- file.path(output_dir, "example_bar_plot_ggplot2.html")
result_bar <- save_html(p_bar, file = html_file_bar)
cat("Bar plot (currency):", if (file.exists(html_file_bar)) "OK" else "FAIL", "\n")

# Test 2: Dodged bar plot with PERCENT formatting
cat("\n=== TEST 2: Dodged Bar Plot (Percent Formatting) ===\n")
dodged_data <- data.frame(
  Category = rep(c("Q1", "Q2", "Q3"), each = 2),
  Metric = rep(c("Growth", "Retention"), 3),
  Value = c(0.12, 0.85, 0.18, 0.92, 0.15, 0.88)
)

p_dodged <- ggplot(dodged_data, aes(x = Category, y = Value, fill = Metric)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(title = "Quarterly Metrics", x = "Quarter", y = "Rate")

html_file_dodged <- file.path(output_dir, "example_dodged_bar_plot_ggplot2.html")
result_dodged <- save_html(p_dodged, file = html_file_dodged)
cat("Dodged bar plot (percent):", if (file.exists(html_file_dodged)) "OK" else "FAIL", "\n")

# Test 3: Stacked bar plot with COMMA formatting for large numbers
cat("\n=== TEST 3: Stacked Bar Plot (Comma Formatting) ===\n")
stacked_data <- data.frame(
  Region = rep(c("North", "South", "East"), each = 2),
  Type = rep(c("Online", "In-Store"), 3),
  Sales = c(125000, 85000, 95000, 110000, 150000, 75000)
)

p_stacked <- ggplot(stacked_data, aes(x = Region, y = Sales, fill = Type)) +
  geom_bar(stat = "identity", position = position_stack()) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(title = "Regional Sales by Channel", x = "Region", y = "Sales Volume")

html_file_stacked <- file.path(output_dir, "example_stacked_bar_plot_ggplot2.html")
result_stacked <- save_html(p_stacked, file = html_file_stacked)
cat("Stacked bar plot (comma):", if (file.exists(html_file_stacked)) "OK" else "FAIL", "\n")

# Test 4: Histogram with FIXED decimal formatting
cat("\n=== TEST 4: Histogram (Fixed Decimal Formatting) ===\n")
set.seed(42)
hist_data <- data.frame(
  values = rnorm(100, mean = 5.5, sd = 1.2)
)

p_hist <- ggplot(hist_data, aes(x = values)) +
  geom_histogram(bins = 20, fill = "steelblue", color = "black") +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  labs(title = "Distribution of Measurements", x = "Value", y = "Count")

html_file_hist <- file.path(output_dir, "example_histogram_ggplot2.html")
result_hist <- save_html(p_hist, file = html_file_hist)
cat("Histogram (fixed decimals):", if (file.exists(html_file_hist)) "OK" else "FAIL", "\n")

# Test 5: Smooth/Density plot with NUMBER formatting
cat("\n=== TEST 5: Smooth Plot (Number Formatting) ===\n")
set.seed(123)
smooth_data <- data.frame(
  x = rnorm(100, mean = 50, sd = 15)
)

p_smooth <- ggplot(smooth_data, aes(x = x)) +
  geom_density(fill = "lightblue", alpha = 0.5) +
  scale_x_continuous(labels = scales::label_number(accuracy = 1)) +
  labs(title = "Score Distribution", x = "Score", y = "Density")

html_file_smooth <- file.path(output_dir, "example_smooth_plot_ggplot2.html")
result_smooth <- save_html(p_smooth, file = html_file_smooth)
cat("Smooth plot (number):", if (file.exists(html_file_smooth)) "OK" else "FAIL", "\n")

# Test 6: Single Line plot with CURRENCY on Y-axis
cat("\n=== TEST 6: Single Line Plot (Currency Y-axis) ===\n")
line_data <- data.frame(
  Month = 1:12,
  Revenue = c(4500, 5200, 4800, 6100, 7200, 6800, 7500, 8200, 7800, 8500, 9200, 10500)
)

p_line <- ggplot(line_data, aes(x = Month, y = Revenue)) +
  geom_line(color = "steelblue", linewidth = 1.5) +
  scale_y_continuous(labels = scales::label_dollar(accuracy = 1)) +
  labs(title = "Monthly Revenue Trend", x = "Month", y = "Revenue") +
  theme_minimal()

html_file_line <- file.path(output_dir, "example_line_plot_ggplot2.html")
result_line <- save_html(p_line, file = html_file_line)
cat("Single line plot (currency):", if (file.exists(html_file_line)) "OK" else "FAIL", "\n")

# Test 7: Multiline plot with PERCENT formatting
cat("\n=== TEST 7: Multiline Plot (Percent Y-axis) ===\n")
set.seed(123)
x <- 1:10
y1 <- cumsum(runif(10, 0.01, 0.05))
y2 <- cumsum(runif(10, 0.02, 0.04))
y3 <- cumsum(runif(10, 0.015, 0.045))

multiline_data <- data.frame(
  Week = rep(x, 3),
  Growth = c(y1, y2, y3),
  Strategy = rep(c("Strategy A", "Strategy B", "Strategy C"), each = length(x))
)

p_multiline <- ggplot(multiline_data, aes(x = Week, y = Growth, color = Strategy)) +
  geom_line(linewidth = 1) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
  labs(
    title = "Growth Rate by Strategy",
    x = "Week",
    y = "Cumulative Growth",
    color = "Strategy"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

html_file_multiline <- file.path(output_dir, "example_multiline_plot_ggplot2.html")
result_multiline <- save_html(p_multiline, file = html_file_multiline)
cat("Multiline plot (percent):", if (file.exists(html_file_multiline)) "OK" else "FAIL", "\n")

# Test 8: Histogram with Density Curve (FIXED formatting)
cat("\n=== TEST 8: Histogram with Density Curve (Fixed Decimals) ===\n")

set.seed(123)
petal_lengths <- rnorm(150, mean = 3.8, sd = 1.8)
petal_data <- data.frame(petal_length = petal_lengths)

p_hist_density <- ggplot(petal_data, aes(x = petal_length)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 0.5, fill = "lightblue", alpha = 0.7, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  labs(
    title = "Petal Lengths in Iris Dataset",
    x = "Petal Length (cm)",
    y = "Density"
  ) +
  theme_minimal()

html_file_hist_density <- file.path(output_dir, "example_histogram_density_ggplot2.html")
result_hist_density <- save_html(p_hist_density, file = html_file_hist_density)
cat("Histogram with density (fixed):", if (file.exists(html_file_hist_density)) "OK" else "FAIL", "\n")

# Test 9: Heatmap with labels (no special formatting needed)
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

html_file_heatmap_labels <- file.path(output_dir, "example_heatmap_with_labels_ggplot2.html")
result_heatmap_labels <- save_html(p_heatmap_labels, file = html_file_heatmap_labels)
cat("Heatmap with labels:", if (file.exists(html_file_heatmap_labels)) "OK" else "FAIL", "\n")

# Test 10: Point/Scatter plot with SCIENTIFIC notation
cat("\n=== TEST 10: Point/Scatter Plot (Scientific Notation) ===\n")
set.seed(123)
point_data <- data.frame(
  x = runif(15, 1e5, 1e7),
  y = runif(15, 1e6, 1e8),
  group = rep(c("A", "B", "C"), each = 5)
)

p_point <- ggplot(point_data, aes(x = x, y = y, color = group)) +
  geom_point(size = 4, alpha = 0.8) +
  scale_x_continuous(labels = scales::label_scientific(digits = 2)) +
  scale_y_continuous(labels = scales::label_scientific(digits = 2)) +
  labs(
    title = "Large Scale Measurements",
    x = "X Value",
    y = "Y Value",
    color = "Group"
  ) +
  theme_minimal()

html_file_point <- file.path(output_dir, "example_point_plot_ggplot2.html")
result_point <- save_html(p_point, file = html_file_point)
cat("Point/Scatter plot (scientific):", if (file.exists(html_file_point)) "OK" else "FAIL", "\n")

# Test 11: Multi-layer plot (Bar + Line) with DUAL formatting
cat("\n=== TEST 11: Multi-Layer Plot (Bar + Line, Currency) ===\n")
dual_plot_data <- data.frame(
  Quarter = c("Q1", "Q2", "Q3", "Q4"),
  Sales = c(45000, 52000, 48000, 61000),
  Target = c(50000, 50000, 55000, 60000)
)

p_dual_axis <- ggplot(dual_plot_data, aes(x = Quarter)) +
  geom_bar(aes(y = Sales), stat = "identity", fill = "skyblue", alpha = 0.7) +
  geom_line(aes(y = Target, group = 1), color = "red", linewidth = 1) +
  scale_y_continuous(labels = scales::label_dollar(accuracy = 1, scale = 0.001, suffix = "K")) +
  labs(
    title = "Sales vs Target",
    x = "Quarter",
    y = "Amount ($K)"
  ) +
  theme_minimal()

html_file_dual_axis <- file.path(output_dir, "example_dual_axis_plot_ggplot2.html")
result_dual_axis <- save_html(p_dual_axis, file = html_file_dual_axis)
cat("Multi-layer plot (currency K):", if (file.exists(html_file_dual_axis)) "OK" else "FAIL", "\n")

# Test 12: Boxplot (Horizontal) with NUMBER formatting
cat("\n=== TEST 12: Boxplot (Horizontal, Number Formatting) ===\n")

iris_data <- datasets::iris

p_box <- ggplot(iris_data, aes(x = Petal.Length, y = Species)) +
  geom_boxplot(fill = "lightblue", color = "darkblue", alpha = 0.7) +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  labs(
    title = "Petal Length by Species from Iris Dataset",
    x = "Petal Length (cm)",
    y = "Species"
  ) +
  theme_minimal()

html_file_box <- file.path(output_dir, "example_boxplot_horizontal_ggplot2.html")
result_box <- save_html(p_box, file = html_file_box)
cat("Boxplot (horizontal, number):", if (file.exists(html_file_box)) "OK" else "FAIL", "\n")

# Test 13: Faceted Bar Plot with COMMA formatting
cat("\n=== TEST 13: Faceted Bar Plot (Comma Formatting) ===\n")
set.seed(42)
facet_bar_data <- data.frame(
  Month = rep(c("Jan", "Feb", "Mar", "Apr", "May"), 4),
  Sales = c(
    runif(5, 10000, 50000),
    runif(5, 20000, 80000),
    runif(5, 15000, 60000),
    runif(5, 25000, 70000)
  ),
  Region = rep(c("North", "South", "East", "West"), each = 5)
)

p_facet_bar <- ggplot(facet_bar_data, aes(x = Month, y = Sales)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  facet_wrap(~Region, ncol = 2) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(
    title = "Monthly Sales by Region",
    x = "Month",
    y = "Sales"
  ) +
  theme_minimal()

html_file_facet_bar <- file.path(output_dir, "example_facet_bar_plot_ggplot2.html")
result_facet_bar <- save_html(p_facet_bar, file = html_file_facet_bar)
cat("Faceted bar plot (comma):", if (file.exists(html_file_facet_bar)) "OK" else "FAIL", "\n")

# Test 14: Faceted Point Plot with FIXED formatting
cat("\n=== TEST 14: Faceted Point Plot (Fixed Decimals) ===\n")
set.seed(42)
facet_point_data <- data.frame(
  x = rep(seq(0.5, 2.5, by = 0.5), 4),
  y = c(
    runif(5, 1, 10),
    runif(5, 5, 15),
    runif(5, 2, 12),
    runif(5, 3, 14)
  ),
  group = rep(c("Group 1", "Group 2", "Group 3", "Group 4"), each = 5)
)

p_facet_point <- ggplot(facet_point_data, aes(x = x, y = y)) +
  geom_point(size = 3, color = "steelblue") +
  facet_wrap(~group, ncol = 2) +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.01)) +
  labs(
    title = "Measurement Comparisons",
    x = "X Values",
    y = "Y Values"
  ) +
  theme_minimal()

html_file_facet_point <- file.path(output_dir, "example_facet_point_plot_ggplot2.html")
result_facet_point <- save_html(p_facet_point, file = html_file_facet_point)
cat("Faceted point plot (fixed):", if (file.exists(html_file_facet_point)) "OK" else "FAIL", "\n")

# Test 15: Faceted Line Plot with PERCENT formatting
cat("\n=== TEST 15: Faceted Line Plot (Percent Formatting) ===\n")
set.seed(42)
facet_line_data <- data.frame(
  Week = rep(1:5, 4),
  Rate = c(
    cumsum(runif(5, 0.01, 0.05)),
    cumsum(runif(5, 0.02, 0.06)),
    cumsum(runif(5, 0.015, 0.045)),
    cumsum(runif(5, 0.025, 0.055))
  ),
  Segment = rep(c("Segment A", "Segment B", "Segment C", "Segment D"), each = 5)
)

p_facet_line <- ggplot(facet_line_data, aes(x = Week, y = Rate)) +
  geom_line(color = "steelblue", linewidth = 1.5) +
  facet_wrap(~Segment, ncol = 2) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(
    title = "Growth Rates by Segment",
    x = "Week",
    y = "Cumulative Rate"
  ) +
  theme_minimal()

html_file_facet_line <- file.path(output_dir, "example_facet_line_plot_ggplot2.html")
result_facet_line <- save_html(p_facet_line, file = html_file_facet_line)
cat("Faceted line plot (percent):", if (file.exists(html_file_facet_line)) "OK" else "FAIL", "\n")

# Test 16: Patchwork 2x2 with MIXED formatting
cat("\n=== TEST 16: Patchwork 2x2 (Mixed Formatting Types) ===\n")

# Build component plots with different formatting
set.seed(99)

# Line plot with currency
line_df_pw <- data.frame(Month = 1:8, Revenue = c(2500, 4200, 3100, 5500, 4300, 6700, 5600, 7800))
pw_line <- ggplot(line_df_pw, aes(Month, Revenue)) +
  geom_line(color = "steelblue", linewidth = 1) +
  scale_y_continuous(labels = scales::label_dollar(accuracy = 1)) +
  labs(title = "Monthly Revenue", x = "Month", y = "Revenue") +
  theme_minimal()

# Bar plot with percent
bar_df1_pw <- data.frame(
  Category = c("A", "B", "C", "D", "E"),
  Rate = c(0.15, 0.22, 0.18, 0.28, 0.17)
)
pw_bar1 <- ggplot(bar_df1_pw, aes(Category, Rate)) +
  geom_bar(stat = "identity", fill = "forestgreen", alpha = 0.7) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(title = "Conversion Rates", x = "Category", y = "Rate") +
  theme_minimal()

# Bar plot with comma (large numbers)
bar_df2_pw <- data.frame(
  Category = c("A", "B", "C", "D", "E"),
  Count = c(125000, 98000, 145000, 112000, 88000)
)
pw_bar2 <- ggplot(bar_df2_pw, aes(Category, Count)) +
  geom_bar(stat = "identity", fill = "royalblue", alpha = 0.7) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(title = "User Counts", x = "Category", y = "Count") +
  theme_minimal()

# Line plot with scientific notation
set.seed(1234)
line_df_extra <- data.frame(x = 1:8, y = 10^(seq(3, 6.5, length.out = 8)))
pw_line_extra <- ggplot(line_df_extra, aes(x, y)) +
  geom_line(color = "tomato", linewidth = 1) +
  scale_y_continuous(labels = scales::label_scientific(digits = 2)) +
  labs(title = "Exponential Growth", x = "Time", y = "Value") +
  theme_minimal()

# Compose 2x2 grid and save
pw_2x2 <- (pw_line + pw_bar1 + pw_bar2 + pw_line_extra) + plot_layout(ncol = 2)
html_file_patchwork_2x2 <- file.path(output_dir, "example_patchwork_2x2_ggplot2.html")
result_patchwork_2x2 <- save_html(pw_2x2, file = html_file_patchwork_2x2)
cat("Patchwork 2x2 (mixed formatting):", if (file.exists(html_file_patchwork_2x2)) "OK" else "FAIL", "\n")


cat("\n=== SUMMARY ===\n")
cat("Generated HTML files in output/ directory:\n")
cat("- Bar plot (currency):", if (file.exists(html_file_bar)) "OK" else "FAIL", "\n")
cat("- Dodged bar plot (percent):", if (file.exists(html_file_dodged)) "OK" else "FAIL", "\n")
cat("- Stacked bar plot (comma):", if (file.exists(html_file_stacked)) "OK" else "FAIL", "\n")
cat("- Histogram (fixed decimals):", if (file.exists(html_file_hist)) "OK" else "FAIL", "\n")
cat("- Smooth plot (number):", if (file.exists(html_file_smooth)) "OK" else "FAIL", "\n")
cat("- Single line plot (currency):", if (file.exists(html_file_line)) "OK" else "FAIL", "\n")
cat("- Multiline plot (percent):", if (file.exists(html_file_multiline)) "OK" else "FAIL", "\n")
cat("- Histogram with density (fixed):", if (file.exists(html_file_hist_density)) "OK" else "FAIL", "\n")
cat("- Heatmap with labels:", if (file.exists(html_file_heatmap_labels)) "OK" else "FAIL", "\n")
cat("- Point/Scatter plot (scientific):", if (file.exists(html_file_point)) "OK" else "FAIL", "\n")
cat("- Multi-layer plot (currency K):", if (file.exists(html_file_dual_axis)) "OK" else "FAIL", "\n")
cat("- Boxplot (horizontal, number):", if (file.exists(html_file_box)) "OK" else "FAIL", "\n")
cat("- Faceted bar plot (comma):", if (file.exists(html_file_facet_bar)) "OK" else "FAIL", "\n")
cat("- Faceted point plot (fixed):", if (file.exists(html_file_facet_point)) "OK" else "FAIL", "\n")
cat("- Faceted line plot (percent):", if (file.exists(html_file_facet_line)) "OK" else "FAIL", "\n")
cat("- Patchwork 2x2 (mixed formatting):", if (file.exists(html_file_patchwork_2x2)) "OK" else "FAIL", "\n")

cat("\n=== FORMATTING TYPES DEMONSTRATED ===\n")
cat("- label_dollar(): Currency formatting (e.g., $1,500.50)\n")
cat("- label_percent(): Percentage formatting (e.g., 15%)\n")
cat("- label_comma(): Large numbers with commas (e.g., 125,000)\n")
cat("- label_number(): Fixed decimal places (e.g., 3.14)\n")
cat("- label_scientific(): Scientific notation (e.g., 1.5e+06)\n")

cat("\nAll examples completed successfully!\n")
cat("Check the output/ directory for interactive HTML files.\n")
