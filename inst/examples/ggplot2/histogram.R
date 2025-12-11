# MAIDR Example: Histogram (ggplot2)
# Demonstrates accessible histogram with keyboard navigation

library(maidr)
library(ggplot2)

# Generate sample data
set.seed(123)
hist_data <- data.frame(values = rnorm(500, mean = 100, sd = 15))

# Create histogram
p <- ggplot(hist_data, aes(x = values)) +
  geom_histogram(bins = 25, fill = "coral", color = "white") +
  labs(
    title = "Distribution of Test Scores",
    x = "Score",
    y = "Frequency"
  ) +
  theme_minimal()

# Display with MAIDR accessibility features
show(p)
