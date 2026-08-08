# Utility functions for grob manipulation

#' Position (1-based) of a layer among the polyline-producing layers of a plot
#'
#' `find_all_polyline_grobs()` returns EVERY polyline in the panel, so the
#' index used to pick one out has to be counted over the same population.
#' `geom_line()` / `geom_path()` / `tidyquant::geom_ma()` (detected as
#' `"line"`) and `geom_step()` (detected as `"step"`) each render one polyline
#' per layer, so both types count. Counting only `"line"` layers would index
#' the wrong polyline for *both* layers of a plot that combines the two.
#'
#' @param plot The ggplot2 object.
#' @param layer_index Index of the layer of interest in `plot$layers`.
#' @return The 1-based position, or NULL when the layer produces no polyline
#'   or registry-based detection fails.
#' @keywords internal
polyline_layer_position <- function(plot, layer_index) {
  tryCatch(
    {
      registry <- get_global_registry()
      adapter <- registry$get_adapter("ggplot2")
      pos <- 0L
      for (i in seq_along(plot$layers)) {
        tp <- adapter$detect_layer_type(plot$layers[[i]], plot)
        if (isTRUE(tp %in% c("line", "step"))) {
          pos <- pos + 1L
          if (i == layer_index) {
            return(pos)
          }
        }
      }
      NULL
    },
    error = function(e) NULL
  )
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
