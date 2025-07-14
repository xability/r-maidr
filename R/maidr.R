#' R-MAIDR: Making ggplot2 Plots Accessible
#' 
#' This package extracts data from ggplot2 plots to make them accessible
#' via JavaScript backend, similar to py-maidr for matplotlib/seaborn.
#' 
#' @docType package
#' @name r-maidr
NULL

#' Display accessible ggplot2 plot in browser
#' 
#' Similar to py-maidr's maidr.show(), this function creates an accessible
#' HTML version of a ggplot2 plot and opens it in the default browser.
#' 
#' @param plot_obj A ggplot2 plot object
#' @param output_file Optional output file name (default: temporary file)
#' @param open_browser Whether to open the result in browser (default: TRUE)
#' @return The path to the generated HTML file (invisibly)
#' @export
maidr.show <- function(plot_obj, output_file = NULL, open_browser = TRUE) {
  if (!inherits(plot_obj, "ggplot")) {
    stop("plot_obj must be a ggplot object")
  }
  
  # Generate temporary file if none provided
  if (is.null(output_file)) {
    output_file <- tempfile(fileext = ".html")
  }
  
  # Create the accessible HTML
  result <- create_maidr_html(plot_obj, output_file)
  
  # Open in browser if requested
  if (open_browser) {
    if (interactive()) {
      utils::browseURL(output_file)
    } else {
      message("HTML file created: ", output_file)
      message("Open this file in your browser to view the accessible plot.")
    }
  }
  
  message("Accessible plot created: ", output_file)
  invisible(output_file)
}

#' Extract MAIDR data from ggplot2 plot
#' 
#' @param plot_obj A ggplot2 plot object
#' @return A list containing MAIDR data structure
#' @export
extract_maidr_data <- function(plot_obj) {
  # Generate unique IDs
  plot_id <- generate_id("plot")
  subplot_id <- generate_id("subplot")
  
  # Extract plot data using ggplot_build
  plot_data <- ggplot_build(plot_obj)
  
  # Extract plot metadata
  metadata <- extract_plot_metadata(plot_obj)
  
  # Process each layer
  layers_result <- process_layers(plot_obj, plot_data)
  layers_data <- layers_result$maidr_layers
  original_data_frames <- layers_result$original_data_frames
  
  # Create the MAIDR data structure
  maidr_data <- list(
    id = plot_id,
    subplots = list(
      list(
        list(
          id = subplot_id,
          layers = layers_data
        )
      )
    )
  )
  
  return(list(maidr_data = maidr_data, plot_df = combine_layer_data(original_data_frames)))
}

#' Process all layers in a ggplot object
#' 
#' @param plot_obj ggplot2 plot object
#' @param plot_data ggplot_build output
#' @return list of processed layer data
process_layers <- function(plot_obj, plot_data) {
  layers <- list()
  original_data_frames <- list()
  
  for (i in seq_along(plot_obj$layers)) {
    layer <- plot_obj$layers[[i]]
    geom_class <- class(layer$geom)[1]
    
    # Get the appropriate extractor
    extractor <- get_extractor(geom_class)
    
    if (!is.null(extractor)) {
      # Extract data using the registered extractor
      layer_result <- extractor(layer, plot_data, i)
      
      # Generate unique layer ID
      layer_id <- generate_id("layer")
      
      # Create MAIDR layer structure
      maidr_layer <- list(
        type = layer_result$type,
        title = layer_result$metadata$title,
        axes = list(
          x = layer_result$metadata$x_label,
          y = layer_result$metadata$y_label
        ),
        data = df_to_maidr_data(layer_result$data),
        selectors = paste0(layer_result$selector, "[maidr='", layer_id, "']")
      )
      
      layers[[length(layers) + 1]] <- maidr_layer
      original_data_frames[[length(original_data_frames) + 1]] <- layer_result$data
    } else {
      warning("No extractor found for geom: ", geom_class)
    }
  }
  
  return(list(maidr_layers = layers, original_data_frames = original_data_frames))
}

#' Combine data from all layers into a single data frame
#' 
#' @param data_frames_list list of data frames
#' @return combined data frame
combine_layer_data <- function(data_frames_list) {
  if (length(data_frames_list) == 0) {
    return(data.frame())
  }
  
  # If we have a list of data frames, bind them together
  if (all(sapply(data_frames_list, is.data.frame))) {
    return(do.call(rbind, data_frames_list))
  }
  
  # If the first element is a data frame, try to bind
  if (is.data.frame(data_frames_list[[1]])) {
    return(do.call(rbind, data_frames_list))
  }
  
  # Fallback: try to convert to data frame
  return(as.data.frame(data_frames_list))
}

#' Create MAIDR HTML with SVG and data
#' 
#' @param plot_obj ggplot2 plot object
#' @param output_file Output HTML file name
#' @export
create_maidr_html <- function(plot_obj, output_file = "maidr_output.html") {
  extraction <- extract_maidr_data(plot_obj)
  maidr_data <- extraction$maidr_data
  plot_df <- extraction$plot_df
  
  # Defensive: coerce plot_df to data frame if not already
  if (!is.data.frame(plot_df)) {
    plot_df <- as.data.frame(do.call(rbind, plot_df))
  }

  # Get the layer_id from the maidr data
  layer_id <- maidr_data$subplots[[1]][[1]]$layers[[1]]$selectors
  layer_id <- gsub(".*maidr='([^']+)'.*", "\\1", layer_id)

  # Save plot as SVG
  svg_file <- tempfile(fileext = ".svg")
  ggplot2::ggsave(svg_file, plot = plot_obj, width = 10, height = 6, dpi = 300)

  # Read SVG content
  svg_content <- readLines(svg_file, warn = FALSE)

  # Get the number of data points
  data_points <- nrow(plot_df)
  
  # Wrap bar rectangles based on data point count
  svg_content <- wrap_bar_rects_by_count(svg_content, data_points)
  
  # Add maidr attribute to the wrapped bar rectangles
  bar_rects <- identify_bar_rectangles_wrapped(svg_content)
  for (i in bar_rects) {
    svg_content[i] <- sub('<rect', paste0('<rect maidr="', layer_id, '"'), svg_content[i])
  }
  svg_content <- paste(svg_content, collapse = "\n")

  # Create HTML with maidr integration
  html_content <- htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8")
    ),
    htmltools::tags$body(
      htmltools::tags$div(
        htmltools::tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist/maidr_style.css"),
        htmltools::tags$script(type = "text/javascript", htmltools::HTML(paste0("
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
        htmltools::tags$div(
          htmltools::HTML(paste0('<svg xmlns:xlink="http://www.w3.org/1999/xlink" xmlns="http://www.w3.org/2000/svg" width="720pt" height="432pt" viewBox="0 0 720 432" version="1.1" maidr-data="', 
                      gsub('"', '&quot;', jsonlite::toJSON(maidr_data, auto_unbox = TRUE)), '">')),
          htmltools::HTML(svg_content),
          htmltools::tags$svg()
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
  
  message("MAIDR HTML file created: ", output_file)
  invisible(maidr_data)
}

# Automatically register extractors when this file is sourced
if (exists("register_default_extractors")) {
  register_default_extractors()
} 