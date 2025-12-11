# MAIDR Example: Heatmap (Base R)
# Demonstrates accessible heatmap with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Create sample correlation-like matrix
heat_matrix <- matrix(
  c(
    1.0, 0.8, 0.3, -0.2,
    0.8, 1.0, 0.5, 0.1,
    0.3, 0.5, 1.0, 0.6,
    -0.2, 0.1, 0.6, 1.0
  ),
  nrow = 4, ncol = 4, byrow = TRUE
)

rownames(heat_matrix) <- c("Var1", "Var2", "Var3", "Var4")
colnames(heat_matrix) <- c("Var1", "Var2", "Var3", "Var4")

# Create color palette
colors <- colorRampPalette(c("blue", "white", "red"))(100)

# Create heatmap
heatmap(heat_matrix,
  Rowv = NA, Colv = NA,
  col = colors,
  scale = "none",
  main = "Correlation Heatmap",
  margins = c(6, 6)
)

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
