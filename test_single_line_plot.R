# Test script for single line plot support in maidr package
# Focus on simple line plots without multiple series or points

library(ggplot2)

# Load maidr package
devtools::load_all("maidr")

# Create simple single line plot data
set.seed(123)
x <- 1:10
y <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)

data <- data.frame(x = x, y = y)

# Create simple line plot (single line)
p_single <- ggplot(data, aes(x = x, y = y)) +
  geom_line() +
  labs(
    title = "Single Line Plot",
    x = "X values", 
    y = "Y values"
  ) +
  theme_minimal()

# Display the plot
print(p_single)

# Analyze the plot structure
cat("\n=== Single Line Plot Analysis ===\n")

# Check plot layers
cat("Number of layers:", length(p_single$layers), "\n")

for (i in seq_along(p_single$layers)) {
  layer <- p_single$layers[[i]]
  cat("Layer", i, ":\n")
  cat("  - Geom class:", class(layer$geom)[1], "\n")
  cat("  - Position class:", class(layer$position)[1], "\n")
  cat("  - Aesthetics:", names(layer$mapping), "\n")
}

# Check data structure
cat("\n=== Data structure ===\n")
cat("Number of rows:", nrow(data), "\n")
cat("Data sample:\n")
print(head(data, 5))

# Test current maidr processing
cat("\n=== Testing current maidr support ===\n")

tryCatch({
  result <- maidr(p_single)
  cat("✓ maidr processed the single line plot\n")
  
  cat("\n=== Result structure ===\n")
  str(result)
  
  if (!is.null(result$data)) {
    cat("\n=== Extracted data ===\n")
    print(result$data)
  }
  
  if (!is.null(result$selectors)) {
    cat("\n=== Generated selectors ===\n")
    print(result$selectors)
  }
  
}, error = function(e) {
  cat("✗ Error processing single line plot:\n")
  cat("Error:", e$message, "\n")
})

# Test with different line aesthetics
cat("\n=== Testing line aesthetics ===\n")

# Line with color
p_color <- ggplot(data, aes(x = x, y = y)) +
  geom_line(color = "red", linewidth = 2) +
  labs(title = "Colored Line")

# Line with linetype
p_linetype <- ggplot(data, aes(x = x, y = y)) +
  geom_line(linetype = "dashed") +
  labs(title = "Dashed Line")

test_plots <- list(
  "color" = p_color,
  "linetype" = p_linetype
)

for (name in names(test_plots)) {
  cat("\nTesting", name, "line plot:\n")
  tryCatch({
    result <- maidr(test_plots[[name]])
    cat("  ✓ Processed successfully\n")
    cat("  - Data points:", length(result$data), "\n")
    cat("  - Selectors:", length(result$selectors), "\n")
  }, error = function(e) {
    cat("  ✗ Error:", e$message, "\n")
  })
}

cat("\n=== Summary for Single Line Plots ===\n")
cat("To support single line plots, we need:\n")
cat("1. Add 'GeomLine' detection in PlotOrchestrator\n")
cat("2. Create LineLayerProcessor class\n")
cat("3. Extract line coordinates (x, y pairs)\n")
cat("4. Generate selectors for SVG path elements\n")
cat("5. Handle line aesthetics (color, linewidth, linetype)\n") 