# Simple test for stacked bar plot with maidr() function
library(ggplot2)

# Load the maidr package
devtools::load_all('maidr')

cat("=== STACKED BAR PLOT EXAMPLE ===\n\n")

# Create stacked bar data with 3 fill categories and 5 bars
stacked_data <- data.frame(
  species = c("Adelie", "Adelie", "Adelie", "Chinstrap", "Chinstrap", "Chinstrap", 
              "Gentoo", "Gentoo", "Gentoo", "Emperor", "Emperor", "Emperor", 
              "Macaroni", "Macaroni", "Macaroni"),
  weight_status = c("Below", "Normal", "Above", "Below", "Normal", "Above", 
                   "Below", "Normal", "Above", "Below", "Normal", "Above", 
                   "Below", "Normal", "Above"),
  count = c(70, 45, 82, 31, 28, 37, 58, 42, 66, 89, 55, 78, 44, 38, 52)
)

# Create a stacked bar plot
p <- ggplot(stacked_data, aes(x = species, y = count, fill = weight_status)) +
  geom_bar(stat = "identity", position = "stack") +
  labs(title = "Penguin Weight Status by Species",
       subtitle = "Stacked Bar Plot with Category-First Reordering",
       x = "Species", 
       y = "Count",
       fill = "Weight Status") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

cat("Created stacked bar plot with 5 species and 3 weight categories\n")
cat("Data order: Category-first, then layer bottom-to-top (Above → Below → Normal)\n\n")

# Test maidr() function - opens in browser
cat("Calling maidr() to open in browser...\n")
maidr(p, open = TRUE)

cat("✓ maidr() completed successfully\n")

# Test save_html() function - saves to file
cat("\nCalling save_html() to save to file...\n")
file_path <- save_html(p, "stacked_bar_example.html")

cat("✓ save_html() completed successfully\n")
cat("✓ HTML file saved at:", file_path, "\n")

cat("\n=== SUMMARY ===\n")
cat("✅ Stacked bar plot created with 5 species × 3 weight categories\n")
cat("✅ Data reordered for correct highlighting (category-first)\n")
cat("✅ maidr() opened plot in browser\n")
cat("✅ save_html() saved plot to file\n")
cat("✅ Perfect highlighting should work for all fill categories!\n") 