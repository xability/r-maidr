#' Generic grob replacement factory
#' 
#' This factory provides a generic interface for finding and replacing grobs
#' based on plot type and element type. It follows the factory pattern to
#' make the system extensible for different plot types.
#' 
#' @param plot_type The type of plot (e.g., "bar")
#' @param element_type The type of element to find (e.g., "rect")
#' @return A function that can find and process grobs of the specified type
#' @export
make_grob_finder <- function(plot_type, element_type = NULL) {
  function(gt, ...) {
    find_grobs_by_type(gt, plot_type, element_type, ...)
  }
}

#' Generic function to find grobs by type
#' @param gt A gtable object (from ggplotGrob)
#' @param plot_type The type of plot
#' @param element_type The type of element to find
#' @param ... Additional arguments
#' @return List of grobs matching the criteria
#' @export
find_grobs_by_type <- function(gt, plot_type, element_type = NULL, ...) {
  # Use switch instead of S3 dispatch since plot_type is a character string
  switch(plot_type,
    "bar" = find_grobs_by_type_bar(gt, plot_type, element_type, ...),
    stop("No grob finder implemented for plot type: ", plot_type)
  )
}

#' Default method for find_grobs_by_type (internal function)
#' @keywords internal
find_grobs_by_type_default <- function(gt, plot_type, element_type = NULL, ...) {
  stop("No grob finder implemented for plot type: ", plot_type)
}

#' Bar plot grob finder (internal function)
#' @keywords internal
find_grobs_by_type_bar <- function(gt, plot_type, element_type = NULL, ...) {
  if (is.null(element_type) || element_type == "rect") {
    return(extract_bar_grobs(gt))
  }
  stop("Unsupported element type for bar plots: ", element_type)
}

#' Generic function to process grobs for a plot using factory pattern
#' @param gt A gtable object (from ggplotGrob)
#' @param plot_type The type of plot (e.g., "bar")
#' @param element_type The type of element to find (defaults to plot-specific)
#' @param ... Additional arguments passed to plot-type-specific functions
#' @return List with original grobs and modified grobs
#' @export
process_grobs_for_plot <- function(gt, plot_type, layer_ids = character(0), element_type = NULL, ...) {
  # Create grob finder using factory pattern
  grob_finder <- make_grob_finder(plot_type, element_type)
  
  # Find grobs based on plot type
  grobs <- grob_finder(gt, plot_type, element_type, ...)
  
  # Note: No need to add attributes to grobs anymore
  # We use existing grob IDs for selectors instead of custom attributes
  
  list(
    original_grobs = grobs,
    modified_grobs = grobs,  # No modifications needed
    plot_type = plot_type,
    element_type = element_type
  )
} 