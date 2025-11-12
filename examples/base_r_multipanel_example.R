#!/usr/bin/env Rscript

# Example script demonstrating Base R multipanel plots with MAIDR
# Tests various layouts: 2x2, 3x2, 2x1 with different plot types

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

cat("=== Base R Multipanel Examples ===\n\n")

# ============================================================
# 2x2 Layout: Four Different Plot Types
# ============================================================
cat("=== 2x2 Multipanel Layout ===\n")

par(mfrow = c(2, 2))

# Panel 1: Scatter plot
set.seed(123)
x1 <- 1:10
y1 <- rnorm(10, mean = 10, sd = 2)
plot(x1, y1,
     main = "Scatter Plot",
     xlab = "X Values",
     ylab = "Y Values",
     pch = 19,
     col = "steelblue")

# Panel 2: Line plot
x2 <- 1:10
y2 <- c(5, 7, 3, 8, 6, 9, 4, 7, 10, 8)
plot(x2, y2,
     type = "l",
     main = "Line Plot",
     xlab = "Time",
     ylab = "Value",
     col = "darkgreen",
     lwd = 2)

# Panel 3: Bar plot
categories <- c("A", "B", "C", "D")
values <- c(30, 25, 15, 10)
barplot(values,
        names.arg = categories,
        main = "Bar Plot",
        xlab = "Category",
        ylab = "Count",
        col = "coral",
        border = "black")

# Panel 4: Histogram
set.seed(456)
hist_data <- rnorm(100, mean = 0, sd = 1)
hist(hist_data,
     main = "Histogram",
     xlab = "Value",
     ylab = "Frequency",
     col = "lightblue",
     border = "black")

# Generate interactive HTML for 2x2 layout
html_file_2x2 <- file.path(output_dir, "example_multipanel_2x2_base_r.html")
save_html(file = html_file_2x2)

cat("✓ 2x2 multipanel layout completed\n")
cat("Generated:", html_file_2x2, "\n\n")

dev.off()

# ============================================================
# 3x2 Layout: Six Scatter Plots
# ============================================================
cat("=== 3x2 Multipanel Layout ===\n")

par(mfrow = c(3, 2))

set.seed(789)
for(i in 1:6) {
  x_vals <- 1:10
  y_vals <- rnorm(10, mean = i * 5, sd = 2)
  plot(x_vals, y_vals,
       main = paste("Panel", i, "- Scatter"),
       xlab = "X Values",
       ylab = "Y Values",
       pch = 19,
       col = rainbow(6)[i])
}

# Generate interactive HTML for 3x2 layout
html_file_3x2 <- file.path(output_dir, "example_multipanel_3x2_base_r.html")
save_html(file = html_file_3x2)

cat("✓ 3x2 multipanel layout completed\n")
cat("Generated:", html_file_3x2, "\n\n")

dev.off()

# ============================================================
# 2x1 Layout: Two Line Plots
# ============================================================
cat("=== 2x1 Multipanel Layout ===\n")

par(mfrow = c(2, 1))

# Panel 1: Line plot with trend
x_trend <- 1:20
y_trend <- 2 * x_trend + rnorm(20, sd = 3)
plot(x_trend, y_trend,
     type = "l",
     main = "Trend Line (Top Panel)",
     xlab = "Time",
     ylab = "Value",
     col = "darkblue",
     lwd = 2)

# Panel 2: Line plot with oscillation
x_osc <- seq(0, 4*pi, length.out = 50)
y_osc <- sin(x_osc) * 10 + rnorm(50, sd = 1)
plot(x_osc, y_osc,
     type = "l",
     main = "Oscillation (Bottom Panel)",
     xlab = "X",
     ylab = "Y",
     col = "darkred",
     lwd = 2)

# Generate interactive HTML for 2x1 layout
html_file_2x1 <- file.path(output_dir, "example_multipanel_2x1_base_r.html")
save_html(file = html_file_2x1)

cat("✓ 2x1 multipanel layout completed\n")
cat("Generated:", html_file_2x1, "\n\n")

dev.off()

# ============================================================
# 1x3 Layout: Three Bar Plots
# ============================================================
cat("=== 1x3 Multipanel Layout ===\n")

par(mfrow = c(1, 3))

# Panel 1: Sales Q1
q1_values <- c(100, 120, 90)
barplot(q1_values,
        names.arg = c("Jan", "Feb", "Mar"),
        main = "Q1 Sales",
        xlab = "Month",
        ylab = "Sales",
        col = "steelblue",
        border = "black")

# Panel 2: Sales Q2
q2_values <- c(110, 130, 95)
barplot(q2_values,
        names.arg = c("Apr", "May", "Jun"),
        main = "Q2 Sales",
        xlab = "Month",
        ylab = "Sales",
        col = "lightgreen",
        border = "black")

# Panel 3: Sales Q3
q3_values <- c(105, 125, 100)
barplot(q3_values,
        names.arg = c("Jul", "Aug", "Sep"),
        main = "Q3 Sales",
        xlab = "Month",
        ylab = "Sales",
        col = "coral",
        border = "black")

# Generate interactive HTML for 1x3 layout
html_file_1x3 <- file.path(output_dir, "example_multipanel_1x3_base_r.html")
save_html(file = html_file_1x3)

cat("✓ 1x3 multipanel layout completed\n")
cat("Generated:", html_file_1x3, "\n\n")

dev.off()

# ============================================================
# 3x3 Layout: Nine Mixed Plots
# ============================================================
cat("=== 3x3 Multipanel Layout ===\n")

par(mfrow = c(3, 3))

set.seed(111)
plot_types <- c("scatter", "line", "bar", "scatter", "line", "bar", "scatter", "line", "bar")

for(i in 1:9) {
  plot_type <- plot_types[i]

  if (plot_type == "scatter") {
    x_vals <- 1:8
    y_vals <- rnorm(8, mean = i * 2, sd = 1)
    plot(x_vals, y_vals,
         main = paste("Panel", i),
         xlab = "X",
         ylab = "Y",
         pch = 19,
         col = rainbow(9)[i])
  } else if (plot_type == "line") {
    x_vals <- 1:8
    y_vals <- seq(i, i + 7, length.out = 8) + rnorm(8, sd = 0.5)
    plot(x_vals, y_vals,
         type = "l",
         main = paste("Panel", i),
         xlab = "X",
         ylab = "Y",
         col = rainbow(9)[i],
         lwd = 2)
  } else if (plot_type == "bar") {
    bar_vals <- c(i, i+2, i+1)
    barplot(bar_vals,
            names.arg = c("A", "B", "C"),
            main = paste("Panel", i),
            xlab = "Cat",
            ylab = "Val",
            col = rainbow(9)[i],
            border = "black")
  }
}

# Generate interactive HTML for 3x3 layout
html_file_3x3 <- file.path(output_dir, "example_multipanel_3x3_base_r.html")
save_html(file = html_file_3x3)

cat("✓ 3x3 multipanel layout completed\n")
cat("Generated:", html_file_3x3, "\n\n")

dev.off()

# ============================================================
# 2x2 mfcol Layout: Column-major Order
# ============================================================
cat("=== 2x2 mfcol Multipanel Layout (Column-major) ===\n")

par(mfcol = c(2, 2))  # Note: mfcol instead of mfrow

# Panel 1 (top-left)
x_vals <- 1:10
y_vals <- rnorm(10, mean = 10, sd = 2)
plot(x_vals, y_vals,
     main = "Panel 1 (Top-Left)",
     xlab = "X",
     ylab = "Y",
     pch = 19,
     col = "red")

# Panel 2 (bottom-left)
x_vals <- 1:10
y_vals <- rnorm(10, mean = 15, sd = 2)
plot(x_vals, y_vals,
     main = "Panel 2 (Bottom-Left)",
     xlab = "X",
     ylab = "Y",
     pch = 19,
     col = "blue")

# Panel 3 (top-right)
x_vals <- 1:10
y_vals <- rnorm(10, mean = 20, sd = 2)
plot(x_vals, y_vals,
     main = "Panel 3 (Top-Right)",
     xlab = "X",
     ylab = "Y",
     pch = 19,
     col = "green")

# Panel 4 (bottom-right)
x_vals <- 1:10
y_vals <- rnorm(10, mean = 25, sd = 2)
plot(x_vals, y_vals,
     main = "Panel 4 (Bottom-Right)",
     xlab = "X",
     ylab = "Y",
     pch = 19,
     col = "purple")

# Generate interactive HTML for 2x2 mfcol layout
html_file_2x2_mfcol <- file.path(output_dir, "example_multipanel_2x2_mfcol_base_r.html")
save_html(file = html_file_2x2_mfcol)

cat("✓ 2x2 mfcol multipanel layout completed\n")
cat("Generated:", html_file_2x2_mfcol, "\n\n")

dev.off()

cat("=== All Multipanel Examples Completed ===\n")
cat("\nGenerated files:\n")
cat("  - ", html_file_2x2, "\n")
cat("  - ", html_file_3x2, "\n")
cat("  - ", html_file_2x1, "\n")
cat("  - ", html_file_1x3, "\n")
cat("  - ", html_file_3x3, "\n")
cat("  - ", html_file_2x2_mfcol, "\n")
