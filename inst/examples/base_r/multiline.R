# MAIDR Example: Multiple Line Plot (Base R)
# Demonstrates accessible multi-series line plot with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Sample data with multiple series
months <- 1:12
product_a <- c(100, 110, 120, 135, 145, 160, 170, 180, 175, 165, 155, 150)
product_b <- c(80, 90, 110, 130, 150, 160, 155, 145, 120, 100, 85, 80)
product_c <- c(120, 125, 130, 128, 135, 180, 175, 140, 135, 130, 125, 120)

# Create matrix for matplot
y_matrix <- cbind(product_a, product_b, product_c)

# Create multi-line plot
matplot(months, y_matrix,
  type = "l",
  main = "Monthly Sales by Product",
  xlab = "Month",
  ylab = "Sales ($)",
  col = c("steelblue", "coral", "forestgreen"),
  lty = 1,
  lwd = 2,
  xaxt = "n"
)

# Add x-axis with month labels
axis(1, at = 1:12, labels = month.abb)

# Add legend
legend("topright",
  legend = c("Product A", "Product B", "Product C"),
  col = c("steelblue", "coral", "forestgreen"),
  lty = 1,
  lwd = 2
)

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
