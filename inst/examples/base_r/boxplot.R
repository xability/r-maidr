# MAIDR Example: Box Plot (Base R)
# Demonstrates accessible boxplot with keyboard navigation

library(maidr)

# Use iris dataset
data(iris)

# Create boxplot
boxplot(Petal.Length ~ Species,
  data = iris,
  main = "Petal Length by Species",
  xlab = "Species",
  ylab = "Petal Length (cm)",
  col = c("lightblue", "lightgreen", "lightyellow"),
  border = "darkblue"
)

# Display with MAIDR accessibility features
show()
