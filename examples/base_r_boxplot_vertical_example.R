#!/usr/bin/env Rscript

# Comprehensive test suite for Base R vertical boxplots
# Tests various edge cases and data configurations

library(devtools)
script_path <- commandArgs(trailingOnly = FALSE)
script_file <- sub("--file=", "", script_path[grep("--file=", script_path)])
script_dir <- dirname(normalizePath(script_file))
maidr_dir <- dirname(script_dir)
load_all(maidr_dir)

output_dir <- file.path(maidr_dir, "output")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("=== Base R Vertical Boxplot Test Suite ===\n\n")

# Test 1: 2 boxes with outliers on both sides
cat("Test 1: Two groups with symmetric outliers (vertical)\n")
set.seed(100)
data1_a <- c(rnorm(25, mean = 100, sd = 8), 60, 65, 70, 130, 135, 140)
data1_b <- c(rnorm(25, mean = 150, sd = 10), 100, 105, 110, 190, 195, 200)
data1 <- list(GroupA = data1_a, GroupB = data1_b)

boxplot(data1, horizontal = FALSE, col = c("lightblue", "lightgreen"),
        main = "Test 1: Two Groups with Symmetric Outliers (Vertical)",
        xlab = "Group", ylab = "Value")

html1_file <- file.path(output_dir, "vertical_test1_two_groups_outliers.html")
save_html(file = html1_file)
cat("  Generated: vertical_test1_two_groups_outliers.html\n")
cat(sprintf("  GroupA: %d samples, GroupB: %d samples\n\n",
            length(data1_a), length(data1_b)))

# Test 2: Multiple boxes with mixed outlier patterns
cat("Test 2: Five groups with mixed outlier patterns (vertical)\n")
set.seed(200)
data2_a <- c(rnorm(20, mean = 50, sd = 5))  # No outliers
data2_b <- c(rnorm(18, mean = 100, sd = 8), 60, 140)  # Both sides
data2_c <- c(rnorm(15, mean = 150, sd = 10), 200, 210)  # Upper only
data2_d <- c(rnorm(22, mean = 200, sd = 12), 140, 150)  # Lower only
data2_e <- c(rnorm(25, mean = 250, sd = 15), 180, 185, 320, 330, 340)  # Many
data2 <- list(G1 = data2_a, G2 = data2_b, G3 = data2_c,
              G4 = data2_d, G5 = data2_e)

boxplot(data2, horizontal = FALSE,
        col = rainbow(5),
        main = "Test 2: Five Groups with Mixed Outlier Patterns (Vertical)",
        xlab = "Group", ylab = "Value")

html2_file <- file.path(output_dir, "vertical_test2_five_groups_mixed.html")
save_html(file = html2_file)
cat("  Generated: vertical_test2_five_groups_mixed.html\n")
cat(sprintf("  Samples: G1=%d, G2=%d, G3=%d, G4=%d, G5=%d\n\n",
            length(data2_a), length(data2_b), length(data2_c),
            length(data2_d), length(data2_e)))

# Test 3: Box with no outliers at the beginning
cat("Test 3: Six groups with no-outlier box first (vertical)\n")
set.seed(300)
data3_a <- rnorm(20, mean = 50, sd = 5)  # No outliers
data3_b <- c(rnorm(18, mean = 100, sd = 8), 60, 140)  # Both sides
data3_c <- c(rnorm(15, mean = 150, sd = 10), 200, 210)  # Upper only
data3_d <- c(rnorm(22, mean = 200, sd = 12), 140, 150)  # Lower only
data3_e <- c(rnorm(25, mean = 250, sd = 15), 180, 185, 320, 330, 340)  # Many
data3_f <- c(rnorm(12, mean = 300, sd = 10), 260)  # Single lower
data3 <- list(G1 = data3_a, G2 = data3_b, G3 = data3_c,
              G4 = data3_d, G5 = data3_e, G6 = data3_f)

boxplot(data3, horizontal = FALSE,
        col = rainbow(6),
        main = "Test 3: Six Groups with No-Outlier Box First (Vertical)",
        xlab = "Group", ylab = "Value")

html3_file <- file.path(output_dir, "vertical_test3_six_groups_no_outlier_first.html")
save_html(file = html3_file)
cat("  Generated: vertical_test3_six_groups_no_outlier_first.html\n")
cat(sprintf("  Samples: G1=%d, G2=%d, G3=%d, G4=%d, G5=%d, G6=%d\n\n",
            length(data3_a), length(data3_b), length(data3_c),
            length(data3_d), length(data3_e), length(data3_f)))

cat("=== All vertical boxplot tests completed successfully ===\n")
cat(sprintf("Generated %d test files in %s directory\n", 3, output_dir))





