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

cat("\n=== Base R Dodged Bar Plot Example ===\n")

# Create a Base R dodged barplot with simple, non-zero values
test_matrix <- matrix(c(
  10, 20, 15,    # Series A values
  15, 25, 20,    # Series B values  
  20, 30, 25     # Series C values
), nrow = 3, byrow = TRUE)

rownames(test_matrix) <- c('A', 'B', 'C')
colnames(test_matrix) <- c('Cat1', 'Cat2', 'Cat3')

# Create dodged barplot
barplot(test_matrix, 
        beside = TRUE,
        col = c('red', 'blue', 'green'),
        legend.text = TRUE,
        args.legend = list(x = 'topright', cex = 0.8),
        main = 'Base R Dodged Bar Plot',
        xlab = 'Categories',
        ylab = 'Values',
        border = 'black')

# Generate interactive HTML
dodged_html_file <- file.path(output_dir, "example_dodged_bar_plot_base_r.html")
show(file = dodged_html_file, open = FALSE)

cat("✓ Base R dodged bar plot example completed\n")
cat("Generated:", dodged_html_file, "\n")
