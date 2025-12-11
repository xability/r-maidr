# MAIDR Example: Faceted Plot (ggplot2)
# Demonstrates accessible faceted plot with keyboard navigation

library(maidr)
library(ggplot2)

# Generate sample data
set.seed(123)
facet_data <- data.frame(
  x = rep(1:5, 4),
  y = c(
    runif(5, 10, 30),
    runif(5, 20, 50),
    runif(5, 15, 40),
    runif(5, 25, 60)
  ),
  group = rep(c("Region A", "Region B", "Region C", "Region D"), each = 5)
)

# Create faceted bar plot
p <- ggplot(facet_data, aes(x = factor(x), y = y)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  facet_wrap(~group, ncol = 2) +
  labs(
    title = "Sales by Region (Faceted View)",
    x = "Quarter",
    y = "Sales ($)"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
