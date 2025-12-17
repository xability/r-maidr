# MAIDR Example: Smooth/Regression Plot (ggplot2)
# Demonstrates accessible scatter plot with smooth line

library(maidr)
library(ggplot2)

# Generate sample data
set.seed(42)
smooth_data <- data.frame(
  x = 1:50,
  y = 2 * (1:50) + rnorm(50, sd = 10)
)

# Create scatter plot with smooth line
p <- ggplot(smooth_data, aes(x = x, y = y)) +
  geom_point(color = "steelblue", size = 2) +
  geom_smooth(method = "loess", color = "red", se = FALSE) +
  labs(
    title = "Scatter Plot with Smooth Line",
    x = "X Values",
    y = "Y Values"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
