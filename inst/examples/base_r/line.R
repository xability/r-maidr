# MAIDR Example: Line Plot (Base R)
# Demonstrates accessible line plot with keyboard navigation

library(maidr)

# Sample time series data with string x-axis labels
x_labels <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
y <- c(5, 7, 3, 8, 6, 9, 4)

# Create line plot with string x-axis
plot(seq_along(x_labels), y,
  type = "l",
  main = "Weekly Sales Trend",
  xlab = "Day of Week",
  ylab = "Sales (thousands)",
  col = "steelblue",
  lwd = 2,
  xaxt = "n"
)
axis(1, at = seq_along(x_labels), labels = x_labels)

# Display with MAIDR accessibility features
show()
