# Simple test for maidr() function - opens plot in browser
library(ggplot2)

# Load the maidr package
devtools::load_all('maidr')

cat("=== SIMPLE MAIDR() TEST ===\n\n")

# Create random data with 10 categories (same as Shiny app)
set.seed(123)
random_data <- data.frame(
  category = paste0("Group ", LETTERS[1:10]),
  value = round(runif(10, 10, 100))
)

# Create a bar plot with 10 bars
p <- ggplot(random_data, aes(x = category, y = value)) + 
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "Random Data - 10 Groups",
       x = "Categories", 
       y = "Values") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

cat("Created bar plot with 10 random bars\n")
cat("Calling maidr() to open in browser...\n")

# This will open the plot in your browser or RStudio Viewer
file_path <- save_html(p, "test_maidr_simple.html")

cat("✓ maidr() completed successfully\n")
cat("✓ HTML file created at:", file_path, "\n")
cat("✓ Plot should be open in your browser/RStudio Viewer\n") 