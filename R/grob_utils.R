# Utility functions for grob manipulation

#' Find the panel grob in a grob tree
#' @param grob_tree The grob tree to search
#' @return The panel grob or NULL if not found
find_panel_grob <- function(grob_tree) {
  if (is.null(grob_tree)) {
    return(NULL)
  }
  for (i in seq_along(grob_tree$grobs)) {
    grob <- grob_tree$grobs[[i]]
    if (!is.null(grob) && !is.null(grob$name) && grepl("^panel-.*\\.gTree", grob$name)) {
      return(grob)
    }
  }
  NULL
}

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
