# MAIDR Example: Dodged Bar Chart (Base R)
# Demonstrates accessible grouped bar chart with keyboard navigation

library(maidr)

# Sample data for grouped comparison
sales_matrix <- matrix(
  c(150, 180, 200, 220, 130, 160, 170, 190),
  nrow = 2, byrow = TRUE
)
rownames(sales_matrix) <- c("Q1", "Q2")
colnames(sales_matrix) <- c("North", "South", "East", "West")

# Create dodged (grouped) bar chart
barplot(sales_matrix,
  beside = TRUE,
  main = "Regional Sales by Quarter",
  xlab = "Region",
  ylab = "Sales ($)",
  col = c("steelblue", "coral"),
  legend.text = rownames(sales_matrix),
  args.legend = list(x = "topright", title = "Quarter")
)

# Display with MAIDR accessibility features
show()
