#!/usr/bin/env Rscript

# Test script for simple histogram plots
library(ggplot2)
devtools::load_all("maidr")

# Create a simple histogram
data <- iris$Petal.Length
plot <- ggplot(data.frame(x = data), aes(x = x)) +
  geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
  labs(title = "Simple Histogram", x = "Petal Length (cm)", y = "Count")

# Test plot type detection
plot_type <- detect_plot_type(plot)

# Test data extraction
histogram_data <- extract_histogram_data(plot)

# Test HTML generation
html_file <- "simple_histogram_test.html"
result <- maidr(plot, file = html_file) 