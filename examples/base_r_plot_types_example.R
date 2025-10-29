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

cat("\n=== Base R Histogram + Density Multi-Layer Example ===\n")

# Create histogram with density overlay
set.seed(42)
data <- rnorm(200, mean = 10, sd = 3)

hist(data,
     probability = TRUE,
     main = "Histogram with Density Curve",
     xlab = "Value",
     ylab = "Density",
     col = "lightblue",
     border = "white",
     breaks = 15)

lines(density(data),
      col = "darkred",
      lwd = 3)

# Generate interactive HTML
multilayer_html_file <- file.path(output_dir, "example_histogram_density_base_r.html")
save_html(file = multilayer_html_file)

cat("✓ Base R histogram + density multi-layer example completed\n")
cat("Generated:", multilayer_html_file, "\n")

cat("\n=== Base R Single Line Plot Example ===\n")

# Create a Base R single line plot
x <- 1:10
y <- c(5, 7, 3, 8, 6, 9, 4, 7, 10, 8)

plot(x, y,
     type = "l",
     main = "Base R Single Line Plot",
     xlab = "X values",
     ylab = "Y values",
     col = "steelblue",
     lwd = 2)

# Generate interactive HTML
line_html_file <- file.path(output_dir, "example_line_plot_base_r.html")
save_html(file = line_html_file)

cat("✓ Base R single line plot example completed\n")
cat("Generated:", line_html_file, "\n")

cat("\n=== Base R Multiline Plot Example ===\n")

# Create a Base R multiline plot using matplot
set.seed(123)
x <- 1:12
y1 <- c(10, 12, 11, 14, 13, 15, 14, 16, 15, 17, 16, 18)
y2 <- c(8, 10, 9, 11, 10, 12, 11, 13, 12, 14, 13, 15)
y3 <- c(15, 17, 16, 18, 17, 19, 18, 20, 19, 21, 20, 22)

y_matrix <- cbind(y1, y2, y3)
colnames(y_matrix) <- c("Product A", "Product B", "Product C")

matplot(x, y_matrix,
        type = "l",
        main = "Base R Multiline Plot (3 Series)",
        xlab = "Month",
        ylab = "Sales",
        col = c("red", "green", "blue"),
        lty = 1,
        lwd = 2)

legend("topright",
       legend = colnames(y_matrix),
       col = c("red", "green", "blue"),
       lty = 1,
       lwd = 2)

# Generate interactive HTML
multiline_html_file <- file.path(output_dir, "example_multiline_plot_base_r.html")
save_html(file = multiline_html_file)

cat("✓ Base R multiline plot example completed\n")
cat("Generated:", multiline_html_file, "\n")
