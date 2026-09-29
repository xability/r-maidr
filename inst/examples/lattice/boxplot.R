# MAIDR Example: Box Plot (lattice) [experimental]
# Demonstrates an accessible lattice box-and-whisker plot with keyboard
# navigation.
#
# Every chart maidr reads from lattice is experimental: none has been through
# a user study, and the reading may change without a deprecation period. A
# bwplot() is read as a box layer, one box per category, with the statistics
# lattice draws it from.

library(maidr)
library(lattice)

# Use iris dataset, as the ggplot2 and Base R box plot examples do
data(iris)

# Create box plot
p <- bwplot(Petal.Length ~ Species,
  data = iris,
  main = "Petal Length by Species",
  xlab = "Species",
  ylab = "Petal Length (cm)"
)

# Display with MAIDR accessibility features
show(p)
