#!/usr/bin/env Rscript

# Test script for Histogram with Density Curve
# Equivalent to seaborn histplot with kde=True

library(ggplot2)
devtools::load_all("maidr")

cat("=== Histogram with Density Curve Test ===\n")
cat("Equivalent to: seaborn.histplot(data, kde=True)\n\n")

# Create sample data equivalent to iris petal lengths
set.seed(123)
petal_lengths <- rnorm(150, mean = 3.8, sd = 1.8)  # Approximate iris petal length distribution
petal_data <- data.frame(petal_length = petal_lengths)

cat("Data summary:\n")
cat("- Sample size:", nrow(petal_data), "\n")
cat("- Mean petal length:", round(mean(petal_data$petal_length), 2), "cm\n")
cat("- SD petal length:", round(sd(petal_data$petal_length), 2), "cm\n")
cat("- Range:", round(range(petal_data$petal_length), 2), "cm\n\n")

# Create histogram with density curve (equivalent to seaborn histplot with kde=True)
p_hist_density <- ggplot(petal_data, aes(x = petal_length)) +
  geom_histogram(aes(y = ..density..), binwidth = 0.5, fill = "lightblue", alpha = 0.7, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(
    title = "Petal Lengths in Iris Dataset",
    x = "Petal Length (cm)",
    y = "Density"
  ) +
  theme_minimal()

cat("Creating plot with:\n")
cat("- Histogram with density scaling (y = ..density..)\n")
cat("- Bin width: 0.5 cm\n")
cat("- Fill color: lightblue with alpha = 0.7\n")
cat("- Border color: black\n")
cat("- Density curve: red with linewidth = 1\n\n")

# Generate HTML with maidr
html_file <- "test_histogram_density.html"
result <- maidr(p_hist_density, file = html_file)

cat("Generated HTML file:", html_file, "\n")
cat("File exists:", file.exists(html_file), "\n")

if (file.exists(html_file)) {
  cat("✓ Test completed successfully!\n")
  
  # Display file size
  file_size <- file.size(html_file)
  cat("File size:", file_size, "bytes\n")
  
  # Check if maidr-data is present in the file
  file_content <- readLines(html_file, n = 20)
  maidr_data_present <- any(grepl("maidr-data", file_content))
  cat("maidr-data present:", maidr_data_present, "\n")
  
} else {
  cat("✗ Test failed - HTML file not created\n")
}

cat("\n=== Test Summary ===\n")
cat("This test replicates the Python code:\n")
cat("```python\n")
cat("import seaborn as sns\n")
cat("import matplotlib.pyplot as plt\n")
cat("import maidr\n\n")
cat("iris = sns.load_dataset(\"iris\")\n")
cat("petal_lengths = iris[\"petal_length\"]\n")
cat("hist_plot = sns.histplot(petal_lengths, kde=True, color=\"blue\", binwidth=0.5)\n")
cat("maidr.show(hist_plot)\n")
cat("```\n") 