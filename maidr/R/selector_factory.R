#' Factory for creating selector functions
#' 
#' This factory creates selector functions based on plot type and element type.
#' It follows the factory pattern to make the system extensible.
#' 
#' @param plot_type The type of plot (e.g., "bar")
#' @param element_type The type of element to target (e.g., "rect")
#' @param layer_id The layer ID to include in the selector
#' @param ... Additional arguments
#' @return A selector string for the specified plot and element type
#' @export
make_selector <- function(plot_type, layer_id, element_type = NULL, ...) {
  # Use switch instead of S3 dispatch since plot_type is a character string
  switch(plot_type,
    "bar" = make_selector_bar(plot_type, layer_id, element_type, ...),
    make_selector_default(plot_type, layer_id, element_type, ...)
  )
}

#' Default method for make_selector (internal function)
#' @keywords internal
make_selector_default <- function(plot_type, layer_id, element_type = NULL, ...) {
  if (is.null(element_type)) {
    return(paste0("*[maidr='", layer_id, "']"))
  }
  return(paste0(element_type, "[maidr='", layer_id, "']"))
}

#' Bar plot selector factory (internal function)
#' @keywords internal
make_selector_bar <- function(plot_type, layer_id, element_type = NULL, ...) {
  if (is.null(element_type)) {
    element_type <- "rect"
  }
  
  # Use existing grob ID instead of custom attributes
  # The grob ID follows the pattern: geom_rect.rect.2.1
  # We need to construct the full grob ID and escape dots for CSS
  grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
  
  # Escape dots in the grob ID for CSS selector
  # CSS treats dots as class selectors, so we need to escape them
  escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
  
  # Selector: #geom_rect\\.rect\\.xxx\\.1 rect
  # This selects all rect elements inside the grob container
  return(paste0("#", escaped_grob_id, " ", element_type))
}

#' Generic function to extract selector for SVG elements (S3 generic)
#' @param svg SVG content or object
#' @param plot_type The type of plot
#' @param layer_id The layer ID
#' @param element_type The type of element to target
#' @param ... Additional arguments
#' @return A selector string
#' @export
extract_selector <- function(svg, plot_type, layer_id, element_type = NULL, ...) {
  make_selector(plot_type, layer_id, element_type, ...)
} 