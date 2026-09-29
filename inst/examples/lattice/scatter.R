# MAIDR Example: Scatter Plot (lattice) [experimental]
# Demonstrates an accessible lattice scatter plot with keyboard navigation.
#
# Every chart maidr reads from lattice is experimental: none has been through
# a user study, and the reading may change without a deprecation period. An
# xyplot() with `groups` is read as one point layer per group, named after
# the group, so a reader moves between the groups as separate layers.

library(maidr)
library(lattice)

# Generate sample data, as the ggplot2 and Base R scatter plot examples do
set.seed(42)
scatter_data <- data.frame(
  x = runif(50, 0, 100),
  y = runif(50, 0, 100),
  group = sample(c("Group A", "Group B", "Group C"), 50, replace = TRUE)
)

# Create scatter plot
p <- xyplot(y ~ x,
  data = scatter_data,
  groups = group,
  auto.key = list(columns = 3),
  main = "Scatter Plot with Groups",
  xlab = "X Variable",
  ylab = "Y Variable"
)

# Display with MAIDR accessibility features
show(p)
