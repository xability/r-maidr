# MAIDR Example: Simple Bar Chart (Base R)
# Demonstrates accessible bar chart with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Sample data
categories <- c("A", "B", "C", "D", "E")
values <- c(30, 45, 25, 60, 35)

# Create bar chart
barplot(values,
  names.arg = categories,
  main = "Simple Bar Chart",
  xlab = "Category",
  ylab = "Value",
  col = "steelblue",
  border = "black"
)

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
