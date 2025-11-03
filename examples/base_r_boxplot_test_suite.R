#!/usr/bin/env Rscript

# Comprehensive test suite for Base R horizontal boxplots
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

cat("=== Base R Boxplot Test Suite ===\n\n")

# Test 1: 2 boxes with many outliers on both sides
cat("Test 1: Two groups with symmetric outliers\n")
set.seed(100)
data1_a <- c(rnorm(25, mean = 100, sd = 8), 60, 65, 70, 130, 135, 140)
data1_b <- c(rnorm(25, mean = 150, sd = 10), 100, 105, 110, 190, 195, 200)
data1 <- list(GroupA = data1_a, GroupB = data1_b)

boxplot(data1, horizontal = TRUE, col = c("lightblue", "lightgreen"),
        main = "Test 1: Two Groups with Symmetric Outliers",
        xlab = "Value", ylab = "Group")

html1_file <- file.path(output_dir, "test1_two_groups_outliers.html")
save_html(file = html1_file)
cat("  Generated: test1_two_groups_outliers.html\n")
cat(sprintf("  GroupA: %d samples, GroupB: %d samples\n\n",
            length(data1_a), length(data1_b)))

# Test 2: 5 boxes with varying sample sizes
cat("Test 2: Five groups with varying sample sizes\n")
set.seed(200)
data2_a <- c(rnorm(10, mean = 50, sd = 5), 30, 35, 70, 75)
data2_b <- c(rnorm(20, mean = 100, sd = 10), 60, 65, 140, 145)
data2_c <- c(rnorm(15, mean = 150, sd = 12), 110)
data2_d <- c(rnorm(30, mean = 200, sd = 15), 150, 155, 250)
data2_e <- c(rnorm(8, mean = 250, sd = 8), 210, 215, 220, 280, 285, 290)
data2 <- list(A = data2_a, B = data2_b, C = data2_c, 
              D = data2_d, E = data2_e)

boxplot(data2, horizontal = TRUE, 
        col = c("coral", "gold", "lightgreen", "skyblue", "plum"),
        main = "Test 2: Five Groups with Varying Sample Sizes",
        xlab = "Measurement", ylab = "Category")

html2_file <- file.path(output_dir, "test2_five_groups_varying.html")
save_html(file = html2_file)
cat("  Generated: test2_five_groups_varying.html\n")
cat(sprintf("  Samples: A=%d, B=%d, C=%d, D=%d, E=%d\n\n",
            length(data2_a), length(data2_b), length(data2_c),
            length(data2_d), length(data2_e)))

# Test 3: 3 boxes with only upper outliers
cat("Test 3: Three groups with only upper outliers\n")
set.seed(300)
data3_a <- c(rnorm(20, mean = 100, sd = 10), 150, 155, 160)
data3_b <- c(rnorm(20, mean = 200, sd = 15), 270, 275)
data3_c <- c(rnorm(20, mean = 300, sd = 20), 400, 410, 420, 430)
data3 <- list(Low = data3_a, Mid = data3_b, High = data3_c)

boxplot(data3, horizontal = TRUE, col = c("salmon", "khaki", "lavender"),
        main = "Test 3: Three Groups with Only Upper Outliers",
        xlab = "Score", ylab = "Level")

html3_file <- file.path(output_dir, "test3_upper_outliers_only.html")
save_html(file = html3_file)
cat("  Generated: test3_upper_outliers_only.html\n")
cat(sprintf("  Low: %d samples, Mid: %d samples, High: %d samples\n\n",
            length(data3_a), length(data3_b), length(data3_c)))

# Test 4: 4 boxes with only lower outliers
cat("Test 4: Four groups with only lower outliers\n")
set.seed(400)
data4_a <- c(rnorm(18, mean = 100, sd = 8), 60, 65)
data4_b <- c(rnorm(22, mean = 150, sd = 12), 90, 95, 100)
data4_c <- c(rnorm(15, mean = 200, sd = 10), 150)
data4_d <- c(rnorm(25, mean = 250, sd = 15), 180, 185, 190, 195)
data4 <- list(T1 = data4_a, T2 = data4_b, T3 = data4_c, T4 = data4_d)

boxplot(data4, horizontal = TRUE, 
        col = c("lightcoral", "lightyellow", "lightcyan", "lightpink"),
        main = "Test 4: Four Groups with Only Lower Outliers",
        xlab = "Temperature", ylab = "Treatment")

html4_file <- file.path(output_dir, "test4_lower_outliers_only.html")
save_html(file = html4_file)
cat("  Generated: test4_lower_outliers_only.html\n")
cat(sprintf("  Samples: T1=%d, T2=%d, T3=%d, T4=%d\n\n",
            length(data4_a), length(data4_b), length(data4_c), length(data4_d)))

# Test 5: 6 boxes with mixed outlier patterns
cat("Test 5: Six groups with mixed outlier patterns\n")
set.seed(500)
data5_a <- rnorm(20, mean = 50, sd = 5)  # No outliers
data5_b <- c(rnorm(18, mean = 100, sd = 8), 60, 140)  # Both sides
data5_c <- c(rnorm(15, mean = 150, sd = 10), 200, 210)  # Upper only
data5_d <- c(rnorm(22, mean = 200, sd = 12), 140, 150)  # Lower only
data5_e <- c(rnorm(25, mean = 250, sd = 15), 180, 185, 320, 330, 340)  # Many
data5_f <- c(rnorm(12, mean = 300, sd = 10), 260)  # Single lower
data5 <- list(G1 = data5_a, G2 = data5_b, G3 = data5_c,
              G4 = data5_d, G5 = data5_e, G6 = data5_f)

boxplot(data5, horizontal = TRUE,
        col = rainbow(6),
        main = "Test 5: Six Groups with Mixed Outlier Patterns",
        xlab = "Value", ylab = "Group")

html5_file <- file.path(output_dir, "test5_six_groups_mixed.html")
save_html(file = html5_file)
cat("  Generated: test5_six_groups_mixed.html\n")
cat(sprintf("  Samples: G1=%d, G2=%d, G3=%d, G4=%d, G5=%d, G6=%d\n\n",
            length(data5_a), length(data5_b), length(data5_c),
            length(data5_d), length(data5_e), length(data5_f)))

cat("=== All tests completed successfully ===\n")
cat("Generated 5 test files in output/ directory\n")

