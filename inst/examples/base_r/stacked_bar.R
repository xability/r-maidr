# MAIDR Example: Stacked Bar Chart (Base R)
# Demonstrates accessible stacked bar chart with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Sample data for stacked comparison
revenue_matrix <- matrix(
  c(
    100, 120, 90,
    150, 100, 180,
    80, 60, 100
  ),
  nrow = 3, byrow = TRUE
)
rownames(revenue_matrix) <- c("Online", "Retail", "Wholesale")
colnames(revenue_matrix) <- c("Product A", "Product B", "Product C")

# Create stacked bar chart
barplot(revenue_matrix,
  beside = FALSE,
  main = "Revenue by Product and Sales Channel",
  xlab = "Product",
  ylab = "Revenue ($)",
  col = c("steelblue", "coral", "forestgreen"),
  legend.text = rownames(revenue_matrix),
  args.legend = list(x = "topright", title = "Channel")
)

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
