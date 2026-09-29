# MAIDR Example: Simple Bar Chart (lattice) [experimental]
# Demonstrates an accessible lattice bar chart with keyboard navigation.
#
# Every chart maidr reads from lattice is experimental: none has been through
# a user study, and the reading may change without a deprecation period. A
# barchart() with no `groups` is read as a bar layer, one bar per category.

library(maidr)
library(lattice)

# The same data as the ggplot2 and Base R bar chart examples
bar_data <- data.frame(
  Category = factor(c("A", "B", "C", "D", "E")),
  Value = c(30, 45, 25, 60, 35)
)

# Create bar chart. lattice starts a bar at the bottom of the axis unless it
# is given an origin; `origin = 0` draws each bar from zero, as the values
# are announced.
p <- barchart(Value ~ Category,
  data = bar_data,
  origin = 0,
  main = "Simple Bar Chart",
  xlab = "Category",
  ylab = "Value"
)

# Display with MAIDR accessibility features
show(p)
