#!/usr/bin/env Rscript

# Test script for maidr package with unified reordering approach
# This script tests all supported plot types and generates HTML files

# Load required libraries
library(ggplot2)
library(devtools)

# Load the maidr package
load_all("maidr")

cat("=== Maidr Package Test - Unified Reordering Approach ===\n")

# Test 1: Simple bar plot
cat("\n=== TEST 1: Simple Bar Plot ===\n")
bar_data <- data.frame(
  Category = c("D", "B", "C", "A"),
  Value = c(10, 25, 15, 30)
)

p_bar <- ggplot(bar_data, aes(x = Category, y = Value)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "Simple Bar Test")

html_file_bar <- "test_maidr_bar.html"
result_bar <- maidr(p_bar, file = html_file_bar)
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

html_file_dodged <- "test_maidr_dodged_bar.html"
result_dodged <- maidr(p_dodged, file = html_file_dodged)
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

html_file_stacked <- "test_maidr_stacked_bar.html"
result_stacked <- maidr(p_stacked, file = html_file_stacked)
cat("Stacked bar plot:", if(file.exists(html_file_stacked)) "✓" else "✗", "\n")

# Test 4: Histogram
cat("\n=== TEST 4: Histogram ===\n")
hist_data <- data.frame(
  values = rnorm(100, mean = 0, sd = 1)
)

p_hist <- ggplot(hist_data, aes(x = values)) +
  geom_histogram(bins = 20, fill = "steelblue", color = "black") +
  labs(title = "Histogram Test")

html_file_hist <- "test_maidr_histogram.html"
result_hist <- maidr(p_hist, file = html_file_hist)
cat("Histogram:", if(file.exists(html_file_hist)) "✓" else "✗", "\n")

# Test 5: Smooth plot
cat("\n=== TEST 5: Smooth Plot ===\n")
smooth_data <- data.frame(
  x = rnorm(100, mean = 0, sd = 1)
)

p_smooth <- ggplot(smooth_data, aes(x = x)) +
  geom_density(fill = "lightblue", alpha = 0.5) +
  labs(title = "Smooth Plot Test")

html_file_smooth <- "test_maidr_smooth.html"
result_smooth <- maidr(p_smooth, file = html_file_smooth)
cat("Smooth plot:", if(file.exists(html_file_smooth)) "✓" else "✗", "\n")

# Test 6: Histogram with Density Curve (Iris Dataset)
cat("\n=== TEST 6: Histogram with Density Curve ===\n")

# Create sample data equivalent to iris petal lengths
set.seed(123)
petal_lengths <- rnorm(150, mean = 3.8, sd = 1.8)  # Approximate iris petal length distribution
petal_data <- data.frame(petal_length = petal_lengths)

# Create histogram with density curve (equivalent to seaborn histplot with kde=True)
p_hist_density <- ggplot(petal_data, aes(x = petal_length)) +
  geom_histogram(aes(y = ..density..), binwidth = 0.5, fill = "lightblue", alpha = 0.7, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(
    title = "Petal Lengths in Iris Dataset",
    x = "Petal Length (cm)",
    y = "Density"
  ) +
  theme_minimal()

html_file_hist_density <- "test_maidr_histogram_density.html"
result_hist_density <- maidr(p_hist_density, file = html_file_hist_density)
cat("Histogram with density curve:", if(file.exists(html_file_hist_density)) "✓" else "✗", "\n")

# Summary
cat("\n=== SUMMARY ===\n")
cat("Generated HTML files:\n")
cat("- Bar plot:", if(file.exists(html_file_bar)) "✓" else "✗", "\n")
cat("- Dodged bar plot:", if(file.exists(html_file_dodged)) "✓" else "✗", "\n")
cat("- Stacked bar plot:", if(file.exists(html_file_stacked)) "✓" else "✗", "\n")
cat("- Histogram:", if(file.exists(html_file_hist)) "✓" else "✗", "\n")
cat("- Smooth plot:", if(file.exists(html_file_smooth)) "✓" else "✗", "\n")
cat("- Histogram with density curve:", if(file.exists(html_file_hist_density)) "✓" else "✗", "\n")

cat("\nAll tests completed with unified reordering approach!\n") 