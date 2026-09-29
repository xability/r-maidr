# MAIDR Example: Conditioned (Faceted) Scatter Plot (lattice) [experimental]
# Demonstrates an accessible multi-panel lattice chart with keyboard
# navigation.
#
# Every chart maidr reads from lattice is experimental: none has been through
# a user study, and the reading may change without a deprecation period.
# Conditioning (`| Species`) draws one panel per level; maidr reads each panel
# as a subplot of its own, named after its strip, in lattice's layout.

library(maidr)
library(lattice)

# Use iris dataset, as the Base R faceted example does: one panel per species
# in a 3 x 1 layout
p <- xyplot(Petal.Width ~ Petal.Length | Species,
  data = iris,
  layout = c(3, 1),
  main = "Petal Size by Species",
  xlab = "Petal Length",
  ylab = "Petal Width"
)

# Display with MAIDR accessibility features
show(p)
