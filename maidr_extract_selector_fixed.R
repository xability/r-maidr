# Maidr extraction with correct SVG selectors
# Install required packages if not already installed
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")
if (!requireNamespace("palmerpenguins", quietly = TRUE)) install.packages("palmerpenguins")
if (!requireNamespace("svglite", quietly = TRUE)) install.packages("svglite")
if (!requireNamespace("htmltools", quietly = TRUE)) install.packages("htmltools")
if (!requireNamespace("jsonlite", quietly = TRUE)) install.packages("jsonlite")
if (!requireNamespace("BrailleR", quietly = TRUE)) install.packages("BrailleR")

library(ggplot2)
library(palmerpenguins)
library(svglite)
library(htmltools)
library(jsonlite)
library(BrailleR)

# Function to extract data from ggplot2 bar plot
extract_maidr_data <- function(plot_obj) {
  # Generate unique IDs
  plot_id <- paste0("plot_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
  subplot_id <- paste0("subplot_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
  layer_id <- paste0("layer_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
  
  # Extract plot data using ggplot_build
  plot_data <- ggplot_build(plot_obj)
  
  # Extract title and labels
  title <- plot_obj$labels$title %||% ""
  x_label <- plot_obj$labels$x %||% ""
  y_label <- plot_obj$labels$y %||% ""
  
  # Extract data from the built plot
  plot_df <- NULL
  
  # Look for bar data in the built plot
  for (i in seq_along(plot_data$data)) {
    layer_data <- plot_data$data[[i]]
    if ("x" %in% names(layer_data) && "y" %in% names(layer_data)) {
      # Get the actual x and y values from the built data
      x_values <- layer_data$x
      y_values <- layer_data$y
      
      # Get the actual x-axis labels from the plot data
      if (is.numeric(x_values)) {
        # If x_values are numeric indices, get the actual factor levels
        original_data <- plot_obj$data
        if (!is.null(original_data)) {
          x_var <- as.character(plot_obj$mapping$x)
          if (length(x_var) == 1 && x_var %in% names(original_data)) {
            x_names <- levels(original_data[[x_var]])[x_values]
          } else {
            x_names <- as.character(x_values)
          }
        } else {
          x_names <- as.character(x_values)
        }
      } else {
        x_names <- as.character(x_values)
      }
      
      plot_df <- data.frame(
        x = x_names,
        y = y_values
      )
      break
    }
  }
  
  # Create the maidr data structure
  maidr_data <- list(
    id = plot_id,
    subplots = list(
      list(
        list(
          id = subplot_id,
          layers = list(
            list(
              type = "bar",
              title = title,
              axes = list(
                x = x_label,
                y = y_label
              ),
              data = lapply(1:nrow(plot_df), function(i) {
                list(
                  x = as.character(plot_df$x[i]),
                  y = as.numeric(plot_df$y[i])
                )
              }),
              selectors = paste0("rect[maidr='", layer_id, "']")
            )
          )
        )
      )
    )
  )
  
  return(list(maidr_data = maidr_data, plot_df = plot_df))
}

# Function to create HTML with maidr integration
create_maidr_html <- function(plot_obj, output_file = "maidr_output.html") {
  # Extract maidr data and plot_df
  extraction <- extract_maidr_data(plot_obj)
  maidr_data <- extraction$maidr_data
  plot_df <- extraction$plot_df

  # Get the layer_id from the maidr data
  layer_id <- maidr_data$subplots[[1]][[1]]$layers[[1]]$selectors
  layer_id <- gsub("rect\\[maidr='([^']+)'\\]", "\\1", layer_id)

  # Save plot as SVG
  svg_file <- "temp_plot.svg"
  ggsave(svg_file, plot = plot_obj, width = 10, height = 6, dpi = 300)

  # Read SVG content
  svg_content <- readLines(svg_file, warn = FALSE)

  # Find and modify rect elements that are bars (have fill color in style)
  for (i in seq_along(svg_content)) {
    if (grepl('<rect.*style=.*fill: #4682B4', svg_content[i])) {
      # Add maidr attribute to the rect element
      svg_content[i] <- gsub('<rect', paste0('<rect maidr="', layer_id, '"'), svg_content[i])
    }
  }

  svg_content <- paste(svg_content, collapse = "\n")
  # --- END revert ---

  # Create HTML with maidr integration
  html_content <- tags$html(
    tags$head(
      tags$meta(charset = "utf-8")
    ),
    tags$body(
      tags$div(
        tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist/maidr_style.css"),
        tags$script(type = "text/javascript", HTML(paste0("
          if (!document.querySelector('script[src=\"https://cdn.jsdelivr.net/npm/maidr@latest/dist/maidr.js\"]')) {
            var script = document.createElement('script');
            script.type = 'module';
            script.src = 'https://cdn.jsdelivr.net/npm/maidr@latest/dist/maidr.js';
            script.addEventListener('load', function() {
              window.main();
            });
            document.head.appendChild(script);
          } else {
            document.addEventListener('DOMContentLoaded', function (e) {
              window.main();
            });
          }
        "))),
        tags$div(
          HTML(paste0('<svg xmlns:xlink="http://www.w3.org/1999/xlink" xmlns="http://www.w3.org/2000/svg" width="720pt" height="432pt" viewBox="0 0 720 432" version="1.1" maidr-data="', 
                      gsub('"', '&quot;', toJSON(maidr_data, auto_unbox = TRUE)), '">')),
          HTML(svg_content),
          tags$svg()
        )
      )
    )
  )
  
  # Write HTML file
  writeLines(as.character(html_content), output_file)
  
  # Clean up temporary SVG file
  if (file.exists(svg_file)) {
    file.remove(svg_file)
  }
  
  cat("Maidr HTML file created:", output_file, "\n")
  cat("Maidr data structure:\n")
  print(toJSON(maidr_data, pretty = TRUE))
  
  return(maidr_data)
}
