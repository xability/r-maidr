# MAIDR Example: Stacked Bar Chart (ggplot2)
# Demonstrates accessible stacked bar chart with keyboard navigation

library(maidr)
library(ggplot2)

# Sample data for stacked comparison
stacked_data <- data.frame(
  Category = rep(c("Product A", "Product B", "Product C"), each = 3),
  Type = rep(c("Online", "Retail", "Wholesale"), 3),
  Revenue = c(100, 150, 80, 120, 100, 60, 90, 180, 100)
)

# Create stacked bar chart
p <- ggplot(stacked_data, aes(x = Category, y = Revenue, fill = Type)) +
  geom_bar(stat = "identity", position = position_stack()) +
  labs(
    title = "Revenue by Product and Sales Channel",
    x = "Product",
    y = "Revenue ($)",
    fill = "Sales Channel"
  ) +
  scale_fill_brewer(palette = "Set1") +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
