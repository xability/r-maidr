#' Scale Mapping Utilities for Faceted Plots
#'
#' These utilities handle the conversion between numeric positions and category labels
#' in faceted plots, where ggplot2 converts categorical data to numeric positions
#' for efficiency.
#'
#' @name scale_mapping_utils
#' @keywords internal
NULL

#' Apply scale mapping to convert numeric positions to category labels
#'
#' In faceted plots, ggplot2 converts categorical x-values to numeric positions
#' (1, 2, 3, ...) for efficiency. This function converts them back to the original
#' category labels using the scale mapping.
#'
#' @param numeric_values Vector of numeric x positions from built plot data
#' @param scale_mapping Named vector mapping positions to labels (e.g., c("1" = "A", "2" = "B"))
#' @return Vector of category labels
#' @keywords internal
apply_scale_mapping <- function(numeric_values, scale_mapping) {
  if (is.null(scale_mapping)) {
    return(numeric_values)
  }

  char_values <- as.character(numeric_values)

  # Map using the scale mapping
  mapped_values <- scale_mapping[char_values]

  # Handle any unmapped values
  unmapped_idx <- is.na(mapped_values)
  if (any(unmapped_idx)) {
    mapped_values[unmapped_idx] <- char_values[unmapped_idx]
  }

  mapped_values
}

#' Extract scale mapping from built plot
#'
#' Extracts the scale mapping from a built ggplot2 plot object. This mapping
#' converts numeric positions back to category labels.
#'
#' @param built Built plot data from ggplot2::ggplot_build()
#' @return Named vector for scale mapping, or NULL if no mapping available
#' @keywords internal
extract_scale_mapping <- function(built) {
  if (is.null(built$layout$panel_scales_x)) {
    return(NULL)
  }

  x_scale <- built$layout$panel_scales_x[[1]]
  breaks <- x_scale$get_breaks()
  labels <- x_scale$get_labels()

  if (is.null(breaks) || is.null(labels)) {
    return(NULL)
  }

  scale_mapping <- setNames(labels, as.character(seq_along(labels)))
  scale_mapping
}
