# MAIDR Example: Heatmap (ggplot2)
# Demonstrates accessible heatmap with keyboard navigation

library(maidr)
library(ggplot2)

# Create sample correlation-like data
heatmap_data <- data.frame(
  x = rep(c("Var1", "Var2", "Var3", "Var4"), each = 4),
  y = rep(c("Var1", "Var2", "Var3", "Var4"), 4),
  value = c(
    1.0, 0.8, 0.3, -0.2,
    0.8, 1.0, 0.5, 0.1,
    0.3, 0.5, 1.0, 0.6,
    -0.2, 0.1, 0.6, 1.0
  )
)

# Create heatmap
p <- ggplot(heatmap_data, aes(x = x, y = y, fill = value)) +
  geom_tile() +
  geom_text(aes(label = round(value, 2)), color = "white", size = 4) +
  scale_fill_gradient2(
    low = "blue", mid = "white", high = "red",
    midpoint = 0, limits = c(-1, 1)
  ) +
  labs(
    title = "Correlation Heatmap",
    x = "",
    y = "",
    fill = "Correlation"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Display with MAIDR accessibility features
show(p)
