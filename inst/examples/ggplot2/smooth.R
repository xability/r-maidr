# MAIDR Example: Density/Smooth Plot (ggplot2)
# Demonstrates accessible density plot with keyboard navigation

library(maidr)
library(ggplot2)

# Generate sample data
set.seed(42)
smooth_data <- data.frame(
  value = c(rnorm(200, mean = 30, sd = 5), rnorm(150, mean = 50, sd = 8)),
  group = c(rep("Group A", 200), rep("Group B", 150))
)

# Create density plot
p <- ggplot(smooth_data, aes(x = value, fill = group)) +
  geom_density(alpha = 0.5) +
  labs(
    title = "Distribution Comparison",
    x = "Value",
    y = "Density",
    fill = "Group"
  ) +
  scale_fill_brewer(palette = "Set2") +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
