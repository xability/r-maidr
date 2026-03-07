# MAIDR Example: Violin Plot (ggplot2)
# Demonstrates accessible violin plot with keyboard navigation
# Violin plots combine KDE density curves with box-summary statistics

library(maidr)
library(ggplot2)

# --- Vertical Violin Plot ---
# Uses mtcars dataset to show MPG distribution by cylinder count
p_vertical <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_violin(fill = "lightblue", alpha = 0.7) +
  labs(
    title = "MPG Distribution by Cylinder Count",
    subtitle = "Violin plot showing density and box-summary statistics",
    x = "Cylinders",
    y = "Miles per Gallon"
  ) +
  theme_minimal()

show(p_vertical)

# --- Horizontal Violin Plot ---
# Uses iris dataset with a discrete y-axis for horizontal orientation
p_horizontal <- ggplot(iris, aes(x = Sepal.Length, y = Species)) +
  geom_violin(fill = "lightgreen", alpha = 0.7) +
  labs(
    title = "Sepal Length Distribution by Species",
    subtitle = "Horizontal violin plot",
    x = "Sepal Length (cm)",
    y = "Species"
  ) +
  theme_minimal()

show(p_horizontal)
