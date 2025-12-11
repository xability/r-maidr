# MAIDR Example: Box Plot (ggplot2)
# Demonstrates accessible boxplot with keyboard navigation

library(maidr)
library(ggplot2)

# Use iris dataset
data(iris)

# Create boxplot
p <- ggplot(iris, aes(x = Species, y = Petal.Length)) +
  geom_boxplot(fill = "lightblue", color = "darkblue", alpha = 0.7) +
  labs(
    title = "Petal Length by Species",
    x = "Species",
    y = "Petal Length (cm)"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
