# MAIDR Example: Histogram (lattice) [experimental]
# Demonstrates an accessible lattice histogram with keyboard navigation.
#
# Every chart maidr reads from lattice is experimental: none has been through
# a user study, and the reading may change without a deprecation period. A
# histogram() is read as a hist layer, one bin per bar lattice draws.

library(maidr)
library(lattice)

# Generate sample data, as the ggplot2 and Base R histogram examples do
set.seed(123)
hist_data <- data.frame(values = rnorm(500, mean = 100, sd = 15))

# Create histogram. lattice shows each bin's percent of the total unless
# asked for counts.
p <- histogram(~values,
  data = hist_data,
  nint = 25,
  type = "count",
  main = "Distribution of Test Scores",
  xlab = "Score",
  ylab = "Frequency"
)

# Display with MAIDR accessibility features
show(p)
