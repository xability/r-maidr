# MAIDR Example: Simple Bar Chart (ggplot2)
# Demonstrates accessible bar chart with keyboard navigation

library(maidr)
library(ggplot2)

# Sample data
bar_data <- data.frame(
  Category = c("A", "B", "C", "D", "E"),
  Value = c(30, 45, 25, 60, 35)
)

# Create bar chart
p <- ggplot(bar_data, aes(x = Category, y = Value)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(
    title = "Simple Bar Chart",
    x = "Category",
    y = "Value"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
