#' Utility functions for robust selector generation in Base R plots
#' 
#' These functions provide a robust way to find grob elements and generate
#' CSS selectors, independent of panel structure or hardcoded values.

#' Find grob by element type pattern
#' 
#' Searches recursively through a grob tree to find a grob whose name matches
#' the pattern: graphics-plot-<number>-<element_type>-<number>
#' 
#' @param grob The grob tree to search (typically from ggplotify::as.grob())
#' @param element_type The element type to search for (e.g., "rect", "lines", "points")
#' @return The name of the first matching grob, or NULL if not found
find_graphics_plot_grob <- function(grob, element_type) {
  # Pattern: graphics-plot-<number>-<element_type>-<number>
  pattern <- paste0("^graphics-plot-[0-9]+-", element_type, "-[0-9]+$")
  
  search_recursive <- function(g) {
    # Check current grob's name
    if (!is.null(g$name)) {
      name <- as.character(g$name)
      if (grepl(pattern, name)) {
        return(name)
      }
    }
    
    # Search in gList (list of grobs)
    if (inherits(g, "gList")) {
      for (i in seq_along(g)) {
        result <- search_recursive(g[[i]])
        if (!is.null(result)) return(result)
      }
    }
    
    # Search in gTree children
    if (inherits(g, "gTree") && !is.null(g$children)) {
      for (i in seq_along(g$children)) {
        result <- search_recursive(g$children[[i]])
        if (!is.null(result)) return(result)
      }
    }
    
    # Search in grobs field (alternative storage used by some grobs)
    if (!is.null(g$grobs)) {
      for (i in seq_along(g$grobs)) {
        result <- search_recursive(g$grobs[[i]])
        if (!is.null(result)) return(result)
      }
    }
    
    return(NULL)
  }
  
  search_recursive(grob)
}

#' Generate robust CSS selector from grob name
#' 
#' Creates a CSS selector that targets SVG elements by their ID pattern,
#' without relying on panel structure or hardcoded values.
#' 
#' @param grob_name The name of the grob (e.g., "graphics-plot-1-rect-1")
#' @param svg_element The SVG element type to target (e.g., "rect", "polyline")
#' @return A robust CSS selector string, or NULL if grob_name is invalid
generate_robust_css_selector <- function(grob_name, svg_element) {
  if (is.null(grob_name) || length(grob_name) == 0 || grob_name == "") {
    return(NULL)
  }
  
  # Add .1 suffix (gridSVG convention for SVG IDs)
  svg_id <- paste0(grob_name, ".1")
  
  # Escape dots for CSS selector syntax
  escaped_id <- gsub("\\.", "\\\\.", svg_id)
  
  # Return attribute selector: <element>[id^='<pattern>']
  # This matches any element whose ID starts with the pattern
  paste0(svg_element, "[id^='", escaped_id, "']")
}

#' Generate robust selector for any element type
#' 
#' Creates a robust CSS selector that works regardless of panel structure.
#' This is the main function that layer processors should use.
#' 
#' @param grob The grob tree to analyze
#' @param element_type The element type to search for (e.g., "rect", "lines")
#' @param svg_element The SVG element to target (e.g., "rect", "polyline")
#' @param max_elements Optional limit on number of elements to target
#' @return A robust CSS selector string, or NULL if element not found
generate_robust_selector <- function(grob, element_type, svg_element, max_elements = NULL) {
  # Find the graphics-plot element for this type
  container_name <- find_graphics_plot_grob(grob, element_type)
  
  if (!is.null(container_name)) {
    # Generate selector using the container name
    base_selector <- generate_robust_css_selector(container_name, svg_element)
    
    # If max_elements is specified, limit the selector to target only that many elements
    if (!is.null(max_elements) && max_elements > 0) {
      # Use nth-child to limit to first N elements
      return(paste0(base_selector, ":nth-child(-n+", max_elements, ")"))
    }
    
    return(base_selector)
  }
  
  return(NULL)
}
