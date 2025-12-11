# MAIDR Example: Density/Smooth Plot (Base R)
# Demonstrates accessible density plot with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Generate sample data
set.seed(42)
values <- rnorm(300, mean = 50, sd = 10)

# Create density plot
dens <- density(values)
plot(dens,
  main = "Density Distribution",
  xlab = "Value",
  ylab = "Density",
  col = "steelblue",
  lwd = 2
)

# Fill under the curve
polygon(dens, col = rgb(0.3, 0.5, 0.7, 0.4), border = "steelblue")

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
