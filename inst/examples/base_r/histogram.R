# MAIDR Example: Histogram (Base R)
# Demonstrates accessible histogram with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Generate sample data
set.seed(123)
values <- rnorm(500, mean = 100, sd = 15)

# Create histogram
hist(values,
  breaks = 25,
  main = "Distribution of Test Scores",
  xlab = "Score",
  ylab = "Frequency",
  col = "coral",
  border = "white"
)

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
