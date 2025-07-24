#' Registry of extractor functions for different geom types
#'
#' This registry maps ggplot2 geom classes to their corresponding
#' extractor functions. New plot types can be added by registering
#' their extractor function here.

# Initialize the extractor registry as an environment for mutability
extractor_registry <- new.env(parent = emptyenv())

#' Register an extractor function for a geom type
#'
#' @param geom_class character geom class name (e.g., "GeomBar")
#' @param extractor_function function to extract data from this geom
#' @export
register_extractor <- function(geom_class, extractor_function) {
  extractor_registry[[geom_class]] <- extractor_function
  invisible(NULL)
}

#' Get extractor function for a geom type
#'
#' @param geom_class character geom class name
#' @return function or NULL if not found
#' @export
get_extractor <- function(geom_class) {
  extractor_registry[[geom_class]]
}

#' Get all registered extractors
#'
#' @return list of registered extractors
#' @export
get_all_extractors <- function() {
  as.list(extractor_registry)
}

# Register the default extractors
register_default_extractors <- function() {
  register_extractor("GeomBar", extract_bar_data)
  register_extractor("GeomCol", extract_bar_data)
}
