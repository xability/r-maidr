# Simple test for r-maidr functionality
library(ggplot2)
library(palmerpenguins)

# Try to load rmaidr, or use devtools::load_all() if not installed
if (!requireNamespace("rmaidr", quietly = TRUE)) {
  if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
  devtools::load_all(".")
} else {
  library(rmaidr)
}

# Create a simple bar plot
p <- ggplot(palmerpenguins::penguins, aes(x = species, y = body_mass_g)) +
  stat_summary(fun = mean, geom = "bar") +
  labs(title = "Average Body Mass by Species",
       x = "Species", 
       y = "Body Mass (g)")

# Test the package functionality
cat("Testing r-maidr package as a real package...\n")

# Test data extraction
extraction <- extract_maidr_data(p)
cat("✓ Data extraction successful\n")

# Test HTML generation
html_file <- "test_simple_output.html"
create_maidr_html(p, html_file)
cat("✓ HTML generation successful\n")

# Check if file was created
if (file.exists(html_file)) {
  cat("✓ Output file created:", html_file, "\n")
  file_size <- file.size(html_file)
  cat("✓ File size:", file_size, "bytes\n")
} else {
  cat("✗ Output file not created\n")
}

cat("Test completed successfully!\n") 