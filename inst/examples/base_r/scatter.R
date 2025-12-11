# MAIDR Example: Scatter Plot (Base R)
# Demonstrates accessible scatter/point plot with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Generate sample data
set.seed(42)
x <- runif(50, 0, 100)
y <- runif(50, 0, 100)
groups <- sample(c("A", "B", "C"), 50, replace = TRUE)
colors <- c("A" = "red", "B" = "blue", "C" = "green")

# Create scatter plot
plot(x, y,
  main = "Scatter Plot with Groups",
  xlab = "X Variable",
  ylab = "Y Variable",
  pch = 19,
  col = colors[groups]
)

# Add legend
legend("topright",
  legend = c("Group A", "Group B", "Group C"),
  col = c("red", "blue", "green"),
  pch = 19
)

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
