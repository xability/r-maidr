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

cat("\n=== Base R Heatmap Example ===\n")

# Create a Base R heatmap
heatmap_data <- matrix(c(
  4, 3,
  2, 1
), nrow = 2, ncol = 2, byrow = TRUE)

colnames(heatmap_data) <- c("A", "B")
rownames(heatmap_data) <- c("2", "1")

# Generate color palette
n_colors <- 100
color_palette <- colorRampPalette(c("darkblue", "blue", "lightblue"))(n_colors)

# Create the heatmap using heatmap() function
heatmap(heatmap_data,
        Rowv = NA, Colv = NA,  # No dendrograms
        col = color_palette,
        scale = "none",
        main = "Base R Heatmap Example",
        xlab = "Columns", ylab = "Rows",
        margins = c(5, 8))

# Generate interactive HTML
heatmap_html_file <- file.path(output_dir, "example_heatmap_base_r.html")
save_html(file = heatmap_html_file)

cat("✓ Base R heatmap example completed\n")
cat("Generated:", heatmap_html_file, "\n")

cat("\n=== Base R Vertical Boxplot Example ===\n")

# Create a Base R vertical boxplot
set.seed(789)
boxplot_data <- list(
  Group1 = rnorm(30, mean = 100, sd = 15),
  Group2 = rnorm(30, mean = 120, sd = 20),
  Group3 = rnorm(30, mean = 110, sd = 18)
)

boxplot(boxplot_data,
        horizontal = FALSE,
        col = c("lightblue", "lightgreen", "lightcoral"),
        main = "Base R Vertical Boxplot",
        xlab = "Group",
        ylab = "Value",
        border = "black")

# Generate interactive HTML
vertical_boxplot_html_file <- file.path(output_dir, "example_boxplot_vertical_base_r.html")
save_html(file = vertical_boxplot_html_file)

cat("✓ Base R vertical boxplot example completed\n")
cat("Generated:", vertical_boxplot_html_file, "\n")

cat("\n=== Base R Horizontal Boxplot Example ===\n")

# Create a Base R horizontal boxplot
set.seed(890)
boxplot_data_h <- list(
  Category_A = rnorm(25, mean = 50, sd = 10),
  Category_B = rnorm(25, mean = 70, sd = 12),
  Category_C = rnorm(25, mean = 60, sd = 11)
)

boxplot(boxplot_data_h,
        horizontal = TRUE,
        col = c("steelblue", "orange", "purple"),
        main = "Base R Horizontal Boxplot",
        xlab = "Value",
        ylab = "Category",
        border = "black")

# Generate interactive HTML
horizontal_boxplot_html_file <- file.path(output_dir, "example_boxplot_horizontal_base_r.html")
save_html(file = horizontal_boxplot_html_file)

cat("✓ Base R horizontal boxplot example completed\n")
cat("Generated:", horizontal_boxplot_html_file, "\n")

cat("\n=== Base R Scatter Plot Example ===\n")

# Create a Base R scatter plot with multiple y values per x
set.seed(123)
x_values <- rep(1:5, each = 3)  # 3 measurements per x value
y_values <- c(rnorm(3, 10, 1), rnorm(3, 15, 2), rnorm(3, 12, 1.5),
              rnorm(3, 18, 1.8), rnorm(3, 14, 0.8))
groups <- rep(c("A", "B", "C"), times = 5)
colors <- rep(c("red", "green", "blue"), times = 5)

plot(x_values, y_values,
     col = colors,
     main = "Base R Scatter Plot (Multiple Y per X)",
     xlab = "X Values",
     ylab = "Y Values",
     pch = 19)

# Generate interactive HTML
scatter_html_file <- file.path(output_dir, "example_scatter_plot_base_r.html")
save_html(file = scatter_html_file)

cat("✓ Base R scatter plot example completed\n")
cat("Generated:", scatter_html_file, "\n")

cat("\n=== Base R Scatter + Linear Regression Example ===\n")

# Create a scatter plot with linear regression line
set.seed(42)
x <- 1:30
y <- 3 * x + 10 + rnorm(30, sd = 5)

plot(x, y,
     main = "Base R Scatter with Linear Regression",
     xlab = "X Variable",
     ylab = "Y Variable",
     pch = 19,
     col = "darkblue")

# Add linear regression line using abline
model <- lm(y ~ x)
abline(model, col = "red", lwd = 2)

# Generate interactive HTML
scatter_lm_html_file <- file.path(output_dir, "example_scatter_linear_regression_base_r.html")
save_html(file = scatter_lm_html_file)

cat("✓ Base R scatter + linear regression example completed\n")
cat("Generated:", scatter_lm_html_file, "\n")

cat("\n=== Base R Scatter + LOESS Smooth Example ===\n")

# Create a scatter plot with LOESS smooth curve
set.seed(42)
x <- seq(0, 10, length.out = 50)
y <- sin(x) * 10 + x * 2 + rnorm(50, sd = 2)

plot(x, y,
     main = "Base R Scatter with LOESS Smooth",
     xlab = "X Variable",
     ylab = "Y Variable",
     pch = 16,
     col = "darkgreen")

# Add LOESS smooth curve using lines and predict
lo <- loess(y ~ x, span = 0.5)
x_seq <- seq(min(x), max(x), length.out = 100)
y_pred <- predict(lo, x_seq)
lines(x_seq, y_pred, col = "purple", lwd = 3)

# Generate interactive HTML
scatter_loess_html_file <- file.path(output_dir, "example_scatter_loess_smooth_base_r.html")
save_html(file = scatter_loess_html_file)

cat("✓ Base R scatter + LOESS smooth example completed\n")
cat("Generated:", scatter_loess_html_file, "\n")
