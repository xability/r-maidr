#!/usr/bin/env Rscript

# Test script for simple smooth plots
library(ggplot2)
devtools::load_all("maidr")

# Create a simple smooth plot
data <- iris$Petal.Length
plot <- ggplot(data.frame(x = data), aes(x = x)) +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Simple Density Plot", x = "Petal Length (cm)", y = "Density")

# Test plot type detection
plot_type <- detect_plot_type(plot)

# Test data extraction
smooth_data <- extract_smooth_data(plot)

# Test HTML generation
html_file <- "simple_smooth_test.html"
result <- maidr(plot, file = html_file) 