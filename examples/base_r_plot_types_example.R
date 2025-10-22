#!/usr/bin/env Rscript

# Example script demonstrating Base R bar plot with MAIDR

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
save_html(file = html_file)

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
save_html(file = dodged_html_file)

cat("✓ Base R dodged bar plot example completed\n")
cat("Generated:", dodged_html_file, "\n")

cat("\n=== Base R Stacked Bar Plot Example ===\n")

# Create a Base R stacked barplot (matrix + beside = FALSE)
stacked_matrix <- matrix(c(
  10, 20, 30,  # Type1
  15, 25, 35   # Type2
), nrow = 2, byrow = TRUE)

rownames(stacked_matrix) <- c("Type1", "Type2")
colnames(stacked_matrix) <- c("A", "B", "C")

barplot(stacked_matrix,
        beside = FALSE,
        col = c("steelblue", "orange"),
        legend.text = rownames(stacked_matrix),
        args.legend = list(x = "topright", bty = "n"),
        main = "Base R Stacked Bar Plot",
        xlab = "Category",
        ylab = "Value",
        border = "black")

# Generate interactive HTML
stacked_html_file <- file.path(output_dir, "example_stacked_bar_plot_base_r.html")
save_html(file = stacked_html_file)

cat("✓ Base R stacked bar plot example completed\n")
cat("Generated:", stacked_html_file, "\n")

cat("\n=== Base R Histogram Example ===\n")

# Create a Base R histogram
set.seed(123)
hist_data <- rnorm(100, mean = 0, sd = 1)

hist(hist_data,
     main = "Base R Histogram",
     xlab = "Values",
     ylab = "Frequency",
     col = "steelblue",
     border = "black")

# Generate interactive HTML
hist_html_file <- file.path(output_dir, "example_histogram_base_r.html")
save_html(file = hist_html_file)

cat("✓ Base R histogram example completed\n")
cat("Generated:", hist_html_file, "\n")

cat("\n=== Base R Density/Smooth Plot Example ===\n")

# Create a Base R density plot
set.seed(456)
density_data <- rnorm(100, mean = 0, sd = 1)

plot(density(density_data),
     main = "Base R Density Plot",
     xlab = "Value",
     ylab = "Density",
     col = "darkblue",
     lwd = 2)

# Generate interactive HTML
density_html_file <- file.path(output_dir, "example_density_plot_base_r.html")
save_html(file = density_html_file)

cat("✓ Base R density plot example completed\n")
cat("Generated:", density_html_file, "\n")
