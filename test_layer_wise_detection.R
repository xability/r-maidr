#!/usr/bin/env Rscript

# Test script for layer-wise detection architecture
# Instead of detecting complex plot types, detect each layer individually

library(ggplot2)

cat("=== LAYER-WISE DETECTION ARCHITECTURE ===\n\n")

# Function to analyze a single layer
analyze_single_layer <- function(layer, layer_index) {
  cat("--- Layer", layer_index, "Analysis ---\n")
  
  # Extract layer components
  geom <- layer$geom
  stat <- layer$stat
  position <- layer$position
  mapping <- layer$mapping
  params <- layer$params
  
  # Get class information
  geom_class <- class(geom)[1]
  stat_class <- class(stat)[1]
  position_class <- class(position)[1]
  
  cat("Geom:", geom_class, "\n")
  cat("Stat:", stat_class, "\n")
  cat("Position:", position_class, "\n")
  
  # Detect layer type based on individual components
  layer_type <- detect_layer_type(geom_class, stat_class, position_class)
  cat("Layer Type:", layer_type, "\n")
  
  # Extract layer-specific information
  layer_info <- list(
    index = layer_index,
    type = layer_type,
    geom_class = geom_class,
    stat_class = stat_class,
    position_class = position_class,
    aesthetics = if (!is.null(mapping)) names(mapping) else character(0),
    parameters = names(params)
  )
  
  cat("Aesthetics:", paste(layer_info$aesthetics, collapse = ", "), "\n")
  cat("Parameters:", paste(layer_info$parameters, collapse = ", "), "\n\n")
  
  return(layer_info)
}

# Function to detect individual layer type
detect_layer_type <- function(geom_class, stat_class, position_class) {
  # Bar-related layers
  if (geom_class %in% c("GeomBar", "GeomCol")) {
    if (stat_class == "StatBin") {
      return("histogram")
    } else if (position_class == "PositionStack") {
      return("stacked_bar")
    } else if (position_class == "PositionDodge") {
      return("dodged_bar")
    } else {
      return("bar")
    }
  }
  
  # Smooth-related layers
  if (geom_class == "GeomSmooth" || stat_class == "StatDensity") {
    return("smooth")
  }
  
  # Line layers
  if (geom_class == "GeomLine") {
    return("line")
  }
  
  # Point layers
  if (geom_class == "GeomPoint") {
    return("point")
  }
  
  # Text layers
  if (geom_class == "GeomText") {
    return("text")
  }
  
  # Error bar layers
  if (geom_class == "GeomErrorbar") {
    return("errorbar")
  }
  
  # Default
  return("unknown")
}

# Function to analyze all layers in a plot
analyze_plot_layers <- function(plot, plot_name) {
  cat("=== Analyzing:", plot_name, "===\n")
  
  layers <- plot$layers
  cat("Total layers:", length(layers), "\n\n")
  
  layer_analyses <- list()
  
  for (i in seq_along(layers)) {
    layer_analysis <- analyze_single_layer(layers[[i]], i)
    layer_analyses[[i]] <- layer_analysis
  }
  
  # Summary
  cat("=== Layer Summary ===\n")
  layer_types <- sapply(layer_analyses, function(x) x$type)
  cat("Layer types:", paste(layer_types, collapse = " + "), "\n")
  
  return(layer_analyses)
}

# Test cases
cat("Test 1: Simple bar plot\n")
p1 <- ggplot(mtcars, aes(factor(cyl))) + geom_bar()
layer_analysis_1 <- analyze_plot_layers(p1, "Simple Bar Plot")

cat("Test 2: Multi-layer plot (bar + text)\n")
p2 <- ggplot(mtcars, aes(factor(cyl))) + 
  geom_bar() + 
  geom_text(aes(label = ..count..), stat = "count", vjust = -0.5)
layer_analysis_2 <- analyze_plot_layers(p2, "Bar + Text")

cat("Test 3: Complex multi-layer plot\n")
p3 <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) + 
  geom_point() + 
  geom_smooth(method = "lm", se = FALSE) +
  geom_text(aes(label = cyl), hjust = -0.5)
layer_analysis_3 <- analyze_plot_layers(p3, "Point + Smooth + Text")

cat("Test 4: Stacked bar plot\n")
p4 <- ggplot(mtcars, aes(factor(cyl), fill = factor(vs))) + 
  geom_bar(position = "stack")
layer_analysis_4 <- analyze_plot_layers(p4, "Stacked Bar")

cat("\n=== ARCHITECTURE INSIGHTS ===\n")
cat("1. Each layer is analyzed independently\n")
cat("2. Layer types: bar, stacked_bar, dodged_bar, histogram, smooth, line, point, text, errorbar\n")
cat("3. Multi-layer plots become combinations of individual layer types\n")
cat("4. Each layer can have its own data extraction and processing\n")
cat("5. Layer order matters for processing sequence\n")
cat("6. Aesthetics and parameters are layer-specific\n")

cat("\n=== PROPOSED ARCHITECTURE ===\n")
cat("1. Layer Detection: Analyze each layer individually\n")
cat("2. Layer Processing: Process each layer with its specific logic\n")
cat("3. Layer Combination: Combine results from multiple layers\n")
cat("4. Data Structure: Each layer gets its own data structure\n")
cat("5. Selector Generation: Generate selectors for each layer\n")
cat("6. Interactive Features: Each layer can have its own interactions\n") 