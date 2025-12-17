# MAIDR Example: Density/Smooth Plot (Base R)
# Demonstrates accessible density plot with keyboard navigation

library(maidr)

# Generate sample data
set.seed(42)
values <- rnorm(300, mean = 50, sd = 10)

# Create density plot
plot(density(values),
  main = "Density Distribution",
  xlab = "Value",
  ylab = "Density",
  col = "steelblue",
  lwd = 2
)

# Display with MAIDR accessibility features
show()
