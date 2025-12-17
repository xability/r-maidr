# MAIDR Example: Multiple Line Plot (ggplot2)
# Demonstrates accessible multi-series line plot with keyboard navigation

library(maidr)
library(ggplot2)

# Sample data with multiple series
multiline_data <- data.frame(
  month = rep(1:12, 3),
  value = c(
    # Series 1: Gradual increase
    c(100, 110, 120, 135, 145, 160, 170, 180, 175, 165, 155, 150),
    # Series 2: Seasonal pattern
    c(80, 90, 110, 130, 150, 160, 155, 145, 120, 100, 85, 80),
    # Series 3: Stable with spike
    c(120, 125, 130, 128, 135, 180, 175, 140, 135, 130, 125, 120)
  ),
  series = rep(c("Product A", "Product B", "Product C"), each = 12)
)

# Create multi-line plot
p <- ggplot(multiline_data, aes(x = month, y = value, color = series)) +
  geom_line(linewidth = 1.2) +
  scale_x_continuous(breaks = 1:12, labels = month.abb) +
  labs(
    title = "Monthly Sales by Product",
    x = "Month",
    y = "Sales ($)",
    color = "Product"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
