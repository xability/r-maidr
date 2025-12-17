# MAIDR Example: Multiple Line Plot (Base R)
# Demonstrates accessible multi-series line plot with keyboard navigation

library(maidr)

# Sample data with multiple series and month labels
month_labels <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
y1 <- c(10, 12, 11, 14, 13, 15, 14, 16, 15, 17, 16, 18)
y2 <- c(8, 10, 9, 11, 10, 12, 11, 13, 12, 14, 13, 15)
y3 <- c(15, 17, 16, 18, 17, 19, 18, 20, 19, 21, 20, 22)

# Create matrix for matplot
y_matrix <- cbind(y1, y2, y3)
colnames(y_matrix) <- c("Product A", "Product B", "Product C")

# Create multi-line plot with string x-axis
matplot(seq_along(month_labels), y_matrix,
  type = "l",
  main = "Monthly Sales by Product",
  xlab = "Month",
  ylab = "Sales (units)",
  col = c("red", "green", "blue"),
  lty = 1,
  lwd = 2,
  xaxt = "n"
)
axis(1, at = seq_along(month_labels), labels = month_labels)

# Add legend
legend("topright",
  legend = colnames(y_matrix),
  col = c("red", "green", "blue"),
  lty = 1,
  lwd = 2
)

# Display with MAIDR accessibility features
show()
