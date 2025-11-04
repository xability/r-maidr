#!/usr/bin/env Rscript

# Example script demonstrating Base R regression plots with MAIDR

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

cat("=== Base R Regression Plot with abline(lm()) ===\n")

# Create a regression plot using abline(lm())
set.seed(42)
x <- 1:20
y <- 2 * x + 1 + rnorm(20, 0, 3)

plot(x, y,
     main = "Regression Plot with abline(lm())",
     xlab = "X values",
     ylab = "Y values",
     pch = 19,
     col = "steelblue")

abline(lm(y ~ x), col = "red", lwd = 2)

# Generate interactive HTML
html_file <- file.path(output_dir, "example_regression_plot_abline_base_r.html")
save_html(file = html_file)

cat("✓ Regression plot with abline(lm()) completed\n")
cat("Generated:", html_file, "\n")

cat("\n=== Base R Regression Plot with abline(a, b) ===\n")

# Create a regression plot using abline(a, b) with direct coefficients
set.seed(123)
x <- seq(0, 10, length.out = 30)
y <- 1.5 * x + 2 + rnorm(30, 0, 2)

plot(x, y,
     main = "Regression Plot with abline(a, b)",
     xlab = "X values",
     ylab = "Y values",
     pch = 16,
     col = "darkgreen")

# Fit model to get coefficients
fit <- lm(y ~ x)
abline(coef(fit)[1], coef(fit)[2], col = "orange", lwd = 2)

# Generate interactive HTML
html_file2 <- file.path(output_dir, "example_regression_plot_abline_coef_base_r.html")
save_html(file = html_file2)

cat("✓ Regression plot with abline(a, b) completed\n")
cat("Generated:", html_file2, "\n")

cat("\n=== Base R Regression Plot with lines() ===\n")

# Create a regression plot using lines() with fitted values
set.seed(456)
x <- 1:15
y <- 3 * x - 2 + rnorm(15, 0, 2.5)

plot(x, y,
     main = "Regression Plot with lines()",
     xlab = "X values",
     ylab = "Y values",
     pch = 17,
     col = "purple")

# Fit model and add regression line using lines()
fit <- lm(y ~ x)
x_range <- seq(min(x), max(x), length.out = 100)
fitted_y <- predict(fit, data.frame(x = x_range))
lines(x_range, fitted_y, col = "darkblue", lwd = 2)

# Generate interactive HTML
html_file3 <- file.path(output_dir, "example_regression_plot_lines_base_r.html")
save_html(file = html_file3)

cat("✓ Regression plot with lines() completed\n")
cat("Generated:", html_file3, "\n")

cat("\n=== Base R Regression Plot with Multiple Lines ===\n")

# Create a scatter plot with multiple regression lines
set.seed(789)
x <- 1:25
y1 <- 2 * x + 5 + rnorm(25, 0, 2)
y2 <- 1.5 * x + 10 + rnorm(25, 0, 2)

plot(x, y1,
     main = "Multiple Regression Lines",
     xlab = "X values",
     ylab = "Y values",
     pch = 19,
     col = "blue",
     ylim = range(c(y1, y2)))

points(x, y2, pch = 19, col = "red")

# Add regression lines for both datasets
abline(lm(y1 ~ x), col = "blue", lwd = 2, lty = 1)
abline(lm(y2 ~ x), col = "red", lwd = 2, lty = 2)

# Generate interactive HTML
html_file4 <- file.path(output_dir, "example_regression_plot_multiple_base_r.html")
save_html(file = html_file4)

cat("✓ Multiple regression lines plot completed\n")
cat("Generated:", html_file4, "\n")

cat("\n=== Base R Regression Plot with Horizontal/Vertical Lines ===\n")

# Create a scatter plot with reference lines
set.seed(999)
x <- 1:18
y <- 10 + rnorm(18, 0, 3)

plot(x, y,
     main = "Scatter Plot with Reference Lines",
     xlab = "X values",
     ylab = "Y values",
     pch = 20,
     col = "darkred")

# Add horizontal and vertical reference lines
abline(h = mean(y), col = "green", lwd = 2, lty = 2)
abline(v = mean(x), col = "orange", lwd = 2, lty = 2)

# Generate interactive HTML
html_file5 <- file.path(output_dir, "example_regression_plot_reference_lines_base_r.html")
save_html(file = html_file5)

cat("✓ Reference lines plot completed\n")
cat("Generated:", html_file5, "\n")

cat("\n=== All regression plot examples completed! ===\n")
