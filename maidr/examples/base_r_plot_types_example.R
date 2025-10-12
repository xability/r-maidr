#!/usr/bin/env Rscript

# Example script demonstrating Base R bar plot with MAIDR

library(devtools)
load_all("maidr")

# Create output directory
output_dir <- "maidr/output"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("=== Base R Bar Plot Example ===\n")

# Create a Base R barplot
barplot(c(30, 25, 15, 10), 
        names.arg = c("A", "B", "C", "D"),
        main = "Simple Base R Bar Plot",
        xlab = "Categories",
        ylab = "Values",
        col = "lightblue",
        border = "black")

# Generate interactive HTML
html_file <- file.path(output_dir, "example_bar_plot_base_r.html")
show(file = html_file, open = FALSE)

cat("✓ Base R bar plot example completed\n")
cat("Generated:", html_file, "\n")
