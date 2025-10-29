#!/usr/bin/env Rscript

# Example script demonstrating Base R line plots with MAIDR

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

cat("=== Base R Single Line Plot Example ===\n")

# Create data equivalent to ggplot2 example
# ggplot2 used: x = 1:10, y = c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
x <- 1:10
y <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)

# Create single line plot
plot(x, y, 
     type = "l",
     main = "Single Line Plot Test",
     xlab = "X values",
     ylab = "Y values",
     col = "steelblue",
     lwd = 1.5)

# Generate interactive HTML
html_file <- file.path(output_dir, "example_single_line_plot_base_r.html")
save_html(file = html_file)

cat("✓ Base R single line plot example completed\n")
cat("Generated:", html_file, "\n")

cat("\n=== Base R Multiline Plot Example (3 Series) ===\n")

# Create data equivalent to ggplot2 multiline example
# ggplot2 used 3 series: y1 = c(2,4,1,5,3,7,6,8,9,4), y2 = c(1,3,5,2,4,6,8,7,5,3), y3 = c(3,1,4,6,5,2,4,5,7,6)
set.seed(123)
x <- 1:10
y1 <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
y2 <- c(1, 3, 5, 2, 4, 6, 8, 7, 5, 3)
y3 <- c(3, 1, 4, 6, 5, 2, 4, 5, 7, 6)

# Combine into matrix for multiline plotting
y_matrix <- cbind(y1, y2, y3)
colnames(y_matrix) <- c("G 1", "G 2", "G 3")

# Create multiline plot using matplot
matplot(x, y_matrix,
        type = "l",
        main = "Multiline Plot Test (3 Series with 10 Points)",
        xlab = "X values",
        ylab = "Y values",
        lty = 1,
        lwd = 1,
        col = c("red", "green", "blue"))

# Add legend
legend("topright",
       legend = c("G 1", "G 2", "G 3"),
       col = c("red", "green", "blue"),
       lty = 1,
       lwd = 1,
       bty = "n")

# Generate interactive HTML
multiline_html_file <- file.path(output_dir, "example_multiline_plot_base_r.html")
save_html(file = multiline_html_file)

cat("✓ Base R multiline plot example completed\n")
cat("Generated:", multiline_html_file, "\n")

cat("\n=== All Base R Line Plot Examples Complete ===\n")

