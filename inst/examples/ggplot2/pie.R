# MAIDR Example: Pie Chart (ggplot2)
# Demonstrates accessible pie chart with keyboard navigation
#
# A ggplot2 pie is a single stacked bar wrapped onto polar coordinates:
# geom_col() supplies the wedge magnitudes and coord_polar("y") bends the
# stack into a circle. Mapping theta to "x" instead would give a coxcomb
# (rose) chart, which MAIDR reads as a bar chart rather than a pie.

library(maidr)
library(ggplot2)

# Sample data
pie_data <- data.frame(
  Category = c("A", "B", "C", "D", "E"),
  Value = c(30, 45, 25, 60, 35)
)

# Create pie chart
p <- ggplot(pie_data, aes(x = "", y = Value, fill = Category)) +
  geom_col(width = 1) +
  coord_polar("y") +
  labs(
    title = "Simple Pie Chart",
    fill = "Category",
    y = "Value"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
