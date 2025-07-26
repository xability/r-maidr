#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' @param plot A ggplot2 object
#' @param file Optional file path to save HTML. If NULL, creates temporary file
#' @param open Whether to open the HTML file in browser/RStudio Viewer
#' @param ... Additional arguments passed to internal functions
#' @export
maidr <- function(plot, file = NULL, open = TRUE, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }
  
  # Create HTML document with maidr enhancements
  html_doc <- create_maidr_html(plot, ...)
  
  # Handle file saving and display
  if (is.null(file)) {
    # Display directly without saving file
    if (open) {
      display_html(html_doc)
    }
    invisible(NULL)
  } else {
    # Save to file and optionally open
    save_html_document(html_doc, file)
    if (open) {
      display_html_file(file)
    }
    invisible(file)
  }
}

#' Save ggplot2 plot as interactive HTML with maidr enhancements
#' @param plot A ggplot2 object
#' @param file Output HTML file path
#' @param ... Additional arguments passed to internal functions
#' @export
save_html <- function(plot, file, ...) {
  stopifnot(inherits(plot, "ggplot"))
  
  # Create HTML document with maidr enhancements
  html_doc <- create_maidr_html(plot, ...)
  
  # Save to file
  save_html_document(html_doc, file)
  
  invisible(file)
}

#' Create HTML document with maidr enhancements
#' @param plot A ggplot2 object
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object
#' @keywords internal
create_maidr_html <- function(plot, ...) {
  # Build the plot and extract layout
  built <- ggplot2::ggplot_build(plot)
  layout <- extract_layout(plot)
  
  # Get plot type using factory pattern
  plot_type <- get_plot_type(plot)
  if (is.na(plot_type)) {
    stop("Unsupported plot type")
  }
  
  # Convert to gtable first to get actual grob numbers
  gt <- ggplotGrob(plot)
  
  # Extract grobs to get the actual grob numbers
  grobs <- find_grobs_by_type(gt, plot_type)
  
  # Generate layer IDs from actual grob numbers
  layer_ids <- character(0)
  if (length(grobs) > 0) {
    for (grob in grobs) {
      grob_name <- grob$name
      # Extract the numeric part from grob name (e.g., "2" from "geom_rect.rect.2")
      layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
      layer_ids <- c(layer_ids, layer_id)
    }
  }
  
  # Extract actual data from the plot using factory pattern
  plot_data <- extract_plot_data(plot, built, layout, plot_type)
  
  # Create layers structure using the actual grob numbers and data
  layers <- list()
  for (i in seq_along(layer_ids)) {
    layer_id <- layer_ids[i]
    
    # Get data for this layer (if available)
    layer_data <- if (i <= length(plot_data)) plot_data[[i]] else list()
    
    layers[[i]] <- list(
      id = layer_id,
      selectors = make_selector(plot_type, layer_id),
      type = plot_type,
      data = layer_data,
      title = if (!is.null(layout$title)) layout$title else "",
      axes = if (!is.null(layout$axes)) layout$axes else list(x = "", y = "")
    )
  }
  
  # Assemble maidr-data structure
  maidr_data <- create_maidr_data(layers)
  
  # Process grobs using the actual layer IDs
  grob_result <- process_grobs_for_plot(gt, plot_type, layer_ids, ...)
  
  # Replace grobs in gtable if any were found
  if (length(grob_result$original_grobs) > 0) {
    gt <- replace_grobs_in_gtable(gt, grob_result$original_grobs, grob_result$modified_grobs)
  }
  
  # Create SVG with proper maidr enhancements
  svg_content <- create_enhanced_svg(gt, plot_type, layer_ids, maidr_data, ...)
  
  # Create HTML document with dependencies
  html_doc <- create_html_document(svg_content)
  
  return(html_doc)
}

#' Create maidr-data structure
#' @param layers List of plot layers
#' @return List containing maidr-data structure
#' @keywords internal
create_maidr_data <- function(layers) {
  # Add missing fields to each layer
  for (i in seq_along(layers)) {
    layer <- layers[[i]]
    
    # Add type field if missing
    if (is.null(layer$type)) {
      layer$type <- "bar"  # Default to bar for now
    }
    
    # Add data field if missing (empty array for now)
    if (is.null(layer$data)) {
      layer$data <- list()
    }
    
    # Add title and axes if missing
    if (is.null(layer$title)) {
      layer$title <- ""
    }
    if (is.null(layer$axes)) {
      layer$axes <- list(x = "", y = "")
    }
    
    layers[[i]] <- layer
  }
  
  list(
    id = paste0("maidr-plot-", as.integer(Sys.time())),
    subplots = list(
      list(
        list(
          id = paste0("maidr-subplot-", as.integer(Sys.time())),
          layers = layers
        )
      )
    )
  )
}

#' Create enhanced SVG with maidr data and layer IDs
#' @param gt A gtable object
#' @param plot_type The type of plot
#' @param layer_ids Character vector of layer IDs
#' @param maidr_data The maidr-data structure
#' @param ... Additional arguments
#' @return Character vector of SVG content
#' @keywords internal
create_enhanced_svg <- function(gt, plot_type, layer_ids, maidr_data, ...) {
  # Export to SVG using gridSVG with proper options
  svg_file <- tempfile(fileext = ".svg")
  library(grid)
  library(gridSVG)
  grid.newpage()
  grid.draw(gt)
  
  # Use gridSVG export options that preserve grob IDs
  grid.export(svg_file, exportCoords = "none", exportMappings = "inline")
  
  # Read SVG content
  svg_content <- readLines(svg_file, warn = FALSE)
  
  # Add maidr-data using proper SVG manipulation
  svg_content <- add_maidr_data_to_svg(svg_content, maidr_data)
  
  # Note: No manual layer ID manipulation needed!
  # We use existing grob IDs (e.g., #geom_rect.rect.2.1) for selectors
  # This is much cleaner and more reliable than custom attributes
  
  return(svg_content)
}

#' Add maidr-data to SVG using proper XML manipulation
#' @param svg_content Character vector of SVG lines
#' @param maidr_data The maidr-data structure
#' @return Modified SVG content
#' @keywords internal
add_maidr_data_to_svg <- function(svg_content, maidr_data) {
  # Convert maidr-data to JSON
  maidr_json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)
  
  # Use XML package for proper SVG manipulation
  if (requireNamespace("xml2", quietly = TRUE)) {
    # Parse SVG as XML
    svg_text <- paste(svg_content, collapse = "\n")
    svg_doc <- xml2::read_xml(svg_text)
    
    # Add maidr-data attribute to root svg element
    xml2::xml_attr(svg_doc, "maidr-data") <- maidr_json
    
    # Convert back to character vector
    svg_content <- strsplit(as.character(svg_doc), "\n")[[1]]
  } else {
    # Fallback to string manipulation (less robust but functional)
    svg_line_index <- grep("^<svg", svg_content)
    if (length(svg_line_index) > 0) {
      svg_line <- svg_content[svg_line_index[1]]
      svg_content[svg_line_index[1]] <- sub(
        "<svg", 
        paste0('<svg maidr-data="', gsub('"', '&quot;', maidr_json), '"'),
        svg_line
      )
    }
  }
  
  return(svg_content)
}

#' Create HTML document with dependencies
#' @param svg_content Character vector of SVG content
#' @return An htmltools HTML document object
#' @keywords internal
create_html_document <- function(svg_content) {
  # Create HTML document
  html_doc <- htmltools::tags$html(
    htmltools::tags$head(),
    htmltools::tags$body(
      htmltools::HTML(paste(svg_content, collapse = "\n"))
    )
  )
  
  # Add CSS and JS dependencies
  html_doc <- htmltools::attachDependencies(html_doc, maidr_html_dependencies())
  
  return(html_doc)
}

#' Save HTML document to file
#' @param html_doc An htmltools HTML document object
#' @param file Output file path
#' @keywords internal
save_html_document <- function(html_doc, file) {
  htmltools::save_html(html_doc, file = file)
}

#' Display HTML document directly
#' @param html_doc An htmltools HTML document object
#' @keywords internal
display_html <- function(html_doc) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(html_doc)
  } else {
    # Use browsable for non-RStudio environments
    print(htmltools::browsable(html_doc))
  }
}

#' Display HTML file in browser
#' @param file HTML file path
#' @keywords internal
display_html_file <- function(file) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(htmltools::includeHTML(file))
  } else {
    utils::browseURL(file)
  }
}

#' Extract all traces/layers from a ggplot2 plot
#' @keywords internal
extract_layers <- function(plot, built, layout) {
  layers <- list()
  
  # Convert to gtable to get actual grob numbers
  gt <- ggplotGrob(plot)
  
  for (i in seq_along(plot$layers)) {
    layer <- plot$layers[[i]]
    geom_class <- class(layer$geom)[1]
    
    # Use factory pattern to determine if this geom is supported
    trace_type <- get_trace_type(geom_class)
    
    if (!is.na(trace_type)) {
      # Extract grobs for this plot type to get the actual grob number
      grobs <- find_grobs_by_type(gt, trace_type)
      
      if (length(grobs) > 0) {
        # Use the grob name to extract the actual number
        grob_name <- grobs[[1]]$name
        layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
      } else {
        # Fallback to layer index if no grobs found
        layer_id <- as.character(i)
      }
      
      trace <- extract_trace(layer, built$data[[i]], layout = layout, layer_id = layer_id)
      layers[[length(layers) + 1]] <- trace
    }
    # Add more geom types here in the future using the factory pattern
  }
  layers
}

#' Extract actual data from ggplot layers using factory pattern
#' @param plot A ggplot2 object
#' @param built The built plot data
#' @param layout Layout information
#' @param plot_type The type of plot
#' @return List of data for each layer
#' @keywords internal
extract_plot_data <- function(plot, built, layout, plot_type) {
  # Use factory pattern to get plot-type-specific data extractor
  data_extractor <- make_data_extractor(plot_type)
  
  plot_data <- list()
  
  for (i in seq_along(plot$layers)) {
    layer <- plot$layers[[i]]
    geom_class <- class(layer$geom)[1]
    
    # Use factory pattern to determine if this geom is supported
    trace_type <- get_trace_type(geom_class)
    
    if (!is.na(trace_type)) {
      # Extract data for this layer using plot-type-specific extractor
      layer_data <- data_extractor(layer, built$data[[i]], layout)
      plot_data[[length(plot_data) + 1]] <- layer_data
    }
  }
  
  return(plot_data)
}

