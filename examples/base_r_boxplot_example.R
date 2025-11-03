#!/usr/bin/env Rscript

# Example script demonstrating Base R boxplot with MAIDR

library(devtools)
# Get the directory where this script is located
script_path <- commandArgs(trailingOnly = FALSE)
script_file <- sub("--file=", "", script_path[grep("--file=", script_path)])
script_dir <- dirname(normalizePath(script_file))
maidr_dir <- dirname(script_dir)  # Parent directory of script directory
load_all(maidr_dir)

# Create output directory
output_dir <- file.path(maidr_dir, "output")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("=== Base R Boxplot Example (Horizontal) ===\n")

# Use iris dataset for boxplot example
iris_data <- datasets::iris

# Create a horizontal boxplot: Petal.Length by Species
boxplot(
  Petal.Length ~ Species,
  data = iris_data,
  horizontal = TRUE,
  main = "Petal Length by Species from Iris Dataset (Base R)",
  xlab = "Petal Length",
  ylab = "Species",
  col = "lightblue",
  border = "darkblue"
)

# Generate interactive HTML
html_file <- file.path(output_dir, "example_boxplot_base_r.html")
save_html(file = html_file)

cat("✓ Base R boxplot example completed\n")
cat("Generated:", html_file, "\n")



