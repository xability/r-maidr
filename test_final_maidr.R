# Test script for final maidr extraction with matching layer_ids
source("maidr_extract_selector_fixed.R")

# Load the penguins dataset
data(penguins)
penguins_clean <- na.omit(penguins)

# Create a bar plot
p <- ggplot(penguins_clean, aes(x = species, y = body_mass_g)) +
  stat_summary(geom = "bar", fun = mean, fill = "steelblue") +
  labs(
    title = "Average Body Mass of Penguins by Species",
    x = "Species",
    y = "Body Mass (g)"
  )

# Display the plot
print(p)

# Create maidr HTML with matching layer_ids
cat("Creating maidr HTML file with MATCHING layer_ids...\n")
maidr_data <- create_maidr_html(p, "penguins_maidr_final.html")

cat("\nFinal maidr extraction complete!\n")
cat("Check the generated 'penguins_maidr_final.html' file\n")
cat("The layer_id in JSON should match the maidr attributes in SVG\n") 