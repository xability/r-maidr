# MAIDR Example: Scatter Plot (ggplot2)
# Demonstrates accessible scatter/point plot with keyboard navigation

library(maidr)
library(ggplot2)

# Generate sample data
set.seed(42)
scatter_data <- data.frame(
  x = runif(50, 0, 100),
  y = runif(50, 0, 100),
  group = sample(c("Group A", "Group B", "Group C"), 50, replace = TRUE)
)

# Create scatter plot
p <- ggplot(scatter_data, aes(x = x, y = y, color = group)) +
  geom_point(size = 3, alpha = 0.7) +
  labs(
    title = "Scatter Plot with Groups",
    x = "X Variable",
    y = "Y Variable",
    color = "Group"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
