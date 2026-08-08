# Utility functions for grob manipulation

#' Find children matching a type pattern
#' @param parent_grob The parent grob to search
#' @param pattern The pattern to match in grob names
#' @return Vector of matching child names
find_children_by_type <- function(parent_grob, pattern) {
  if (is.null(parent_grob) || is.null(parent_grob$children)) {
    return(character(0))
  }

  child_names <- names(parent_grob$children)
  if (is.null(child_names)) {
    return(character(0))
  }

  matching <- grepl(pattern, child_names)
  child_names[matching]
}
