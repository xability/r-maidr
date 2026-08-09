# MAIDR Example: Pie Chart (Base R)
# Demonstrates accessible pie chart with keyboard navigation

library(maidr)

# Sample data
values <- c(30, 45, 25, 60, 35)
names(values) <- c("A", "B", "C", "D", "E")

# Create pie chart
pie(values,
  main = "Simple Pie Chart",
  col = c("steelblue", "coral", "seagreen", "goldenrod", "orchid")
)

# Display with MAIDR accessibility features
show()
