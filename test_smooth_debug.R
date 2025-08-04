# Debug script to check layer ID extraction for smooth plots
library(ggplot2)
library(gridSVG)
devtools::load_all("maidr")

# Create a simple smooth plot
data <- data.frame(x = rnorm(100))
p <- ggplot(data, aes(x = x)) + 
  geom_density() +
  labs(title = "Debug Smooth Plot")

# Convert to gtable
gt <- ggplot2::ggplotGrob(p)

# Debug: Print all grob names
cat("=== All grob names ===\n")
for (i in seq_along(gt$grobs)) {
  grob <- gt$grobs[[i]]
  cat("Grob", i, "name:", grob$name, "\n")
  
  # If it's a gTree, check children
  if (inherits(grob, "gTree")) {
    for (j in seq_along(grob$children)) {
      child <- grob$children[[j]]
      cat("  Child", j, "name:", child$name, "\n")
      
      # If child is also a gTree, check its children
      if (inherits(child, "gTree")) {
        for (k in seq_along(child$children)) {
          grandchild <- child$children[[k]]
          cat("    Grandchild", k, "name:", grandchild$name, "\n")
        }
      }
    }
  }
}

# Test the polyline extraction
cat("\n=== Polyline extraction test ===\n")
polylines <- maidr:::find_polyline_grobs(gt)
cat("Found", length(polylines), "polyline grobs\n")
for (i in seq_along(polylines)) {
  cat("Polyline", i, "name:", polylines[[i]]$name, "\n")
}

# Test layer ID extraction
cat("\n=== Layer ID extraction test ===\n")
layer_ids <- maidr:::extract_polyline_layer_ids_from_gtable(gt)
cat("Extracted layer IDs:", layer_ids, "\n")

# Test the full process
cat("\n=== Full process test ===\n")
result <- maidr::maidr(p)
cat("Result type:", class(result), "\n") 