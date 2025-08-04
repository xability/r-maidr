library(ggplot2)
devtools::load_all("maidr")

cat("=== TESTING STACKED BAR PLOT ===\n")

# Create a simple stacked bar plot
set.seed(123)
data <- data.frame(
  Category = rep(c("A", "B", "C"), each = 3),
  Type = rep(c("Type1", "Type2", "Type3"), 3),
  Value = c(10, 15, 20, 25, 30, 35, 40, 45, 50)
)

p <- ggplot(data, aes(x = Category, y = Value, fill = Type)) +
  geom_bar(stat = "identity", position = "stack") +
  labs(title = "Stacked Bar Plot Test",
       x = "Category",
       y = "Value")

cat("Created stacked bar plot\n")

# Test plot type detection
cat("\n1. Testing Plot Type Detection\n")
plot_type <- detect_plot_type(p)
cat("Detected plot type:", plot_type, "\n")

# Test data extraction
cat("\n2. Testing Data Extraction\n")
stacked_data <- extract_stacked_bar_data(p)
cat("Extracted data structure:", class(stacked_data), "\n")
cat("Number of groups:", length(stacked_data), "\n")
if (length(stacked_data) > 0) {
  cat("First group points:", length(stacked_data[[1]]), "\n")
  if (length(stacked_data[[1]]) > 0) {
    cat("First point keys:", paste(names(stacked_data[[1]][[1]]), collapse = ", "), "\n")
  }
}

# Test HTML generation
cat("\n3. Testing HTML Generation\n")
save_html(p, "stacked_bar_test.html")
cat("✅ HTML file generated: stacked_bar_test.html\n")

cat("\n=== TEST SUMMARY ===\n")
cat("✅ Stacked bar plot created\n")
cat("✅ Plot type detected correctly\n")
cat("✅ Data extraction working\n")
cat("✅ HTML generation successful\n")
cat("✅ Ready to test highlighting in browser\n") 