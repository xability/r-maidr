# MAIDR Example: Line Plot (Base R)
# Demonstrates accessible line plot with keyboard navigation

library(maidr)

# Use null device to prevent graphics window from opening
pdf(NULL)

# Sample time series data
months <- 1:12
sales <- c(120, 150, 180, 200, 220, 250, 230, 210, 190, 170, 160, 180)

# Create line plot
plot(months, sales,
  type = "l",
  main = "Monthly Sales Trend",
  xlab = "Month",
  ylab = "Sales ($)",
  col = "steelblue",
  lwd = 2,
  xaxt = "n"
)

# Add x-axis with month labels
axis(1, at = 1:12, labels = month.abb)

# Add points
points(months, sales, pch = 19, col = "steelblue")

# Display with MAIDR accessibility features
show()

# Close the null device
dev.off()
