# MAIDR Example: Dodged Bar Chart (ggplot2)
# Demonstrates accessible grouped bar chart with keyboard navigation

library(maidr)
library(ggplot2)

# Sample data for grouped comparison
dodged_data <- data.frame(
  Region = rep(c("North", "South", "East", "West"), each = 2),
  Quarter = rep(c("Q1", "Q2"), 4),
  Sales = c(150, 180, 200, 220, 130, 160, 170, 190)
)

# Create dodged bar chart
p <- ggplot(dodged_data, aes(x = Region, y = Sales, fill = Quarter)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8)) +
  labs(
    title = "Regional Sales by Quarter",
    x = "Region",
    y = "Sales ($)",
    fill = "Quarter"
  ) +
  scale_fill_brewer(palette = "Set2") +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
