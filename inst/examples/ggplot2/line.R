# MAIDR Example: Line Plot (ggplot2)
# Demonstrates accessible line plot with keyboard navigation

library(maidr)
library(ggplot2)

# Sample time series data
line_data <- data.frame(
  month = 1:12,
  sales = c(120, 150, 180, 200, 220, 250, 230, 210, 190, 170, 160, 180)
)

# Create line plot (single layer)
p <- ggplot(line_data, aes(x = month, y = sales)) +
  geom_line(color = "steelblue", linewidth = 1.5) +
  scale_x_continuous(breaks = 1:12, labels = month.abb) +
  labs(
    title = "Monthly Sales Trend",
    x = "Month",
    y = "Sales ($)"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
