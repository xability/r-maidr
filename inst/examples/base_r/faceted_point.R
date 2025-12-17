# MAIDR Example: Faceted Point Plot (Base R)
# Demonstrates accessible multi-panel layout using par(mfrow)

library(maidr)

# Use iris dataset - facet by Species (1x3 layout)
species_levels <- unique(iris$Species)

# Set up 1x3 panel layout
par(mfrow = c(1, 3))

# Create a scatter plot for each species
for (species in species_levels) {
  subset_data <- iris[iris$Species == species, ]
  plot(subset_data$Petal.Length, subset_data$Petal.Width,
    main = paste("Species:", species),
    xlab = "Petal Length",
    ylab = "Petal Width",
    pch = 19,
    col = "steelblue"
  )
}

# Display with MAIDR accessibility features
show()
