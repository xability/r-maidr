#' Base R Function Classification
#'
#' This module classifies Base R plotting functions into categories:
#' - HIGH: Main plot creation functions (barplot, hist, plot, etc.)
#' - LOW: Drawing functions that add to existing plots (lines, points, etc.)
#' - LAYOUT: Canvas layout functions (par, layout, etc.)
#'
#' @keywords internal

#' Function Classification Maps
#'
#' @description Maps of function names to their classification levels
#' @keywords internal
.base_r_function_classes <- list(
  HIGH = c(
    "barplot",
    "plot",
    "hist",
    "boxplot",
    "image",
    "contour",
    "matplot",
    "curve",
    "dotchart",
    "stripchart",
    "stem",
    "pie",
    "mosaicplot",
    "assocplot",
    "pairs",
    "coplot"
  ),
  
  LOW = c(
    "lines",
    "points",
    "text",
    "mtext",
    "abline",
    "segments",
    "arrows",
    "polygon",
    "rect",
    "symbols",
    "legend",
    "axis",
    "title",
    "grid"
  ),
  
  LAYOUT = c(
    "par",
    "layout",
    "split.screen"
  )
)

#' Classify a Base R Function
#'
#' Determines the classification level of a Base R plotting function.
#'
#' @param function_name Name of the function to classify
#' @return Character string: "HIGH", "LOW", "LAYOUT", or "UNKNOWN"
#' @keywords internal
classify_function <- function(function_name) {
  if (is.null(function_name) || !is.character(function_name)) {
    return("UNKNOWN")
  }
  
  base_name <- sub("\\.default$", "", function_name)
  
  if (base_name %in% .base_r_function_classes$HIGH) {
    return("HIGH")
  } else if (base_name %in% .base_r_function_classes$LOW) {
    return("LOW")
  } else if (base_name %in% .base_r_function_classes$LAYOUT) {
    return("LAYOUT")
  } else {
    return("UNKNOWN")
  }
}

#' Get All Functions of a Specific Class
#'
#' Returns all function names for a given classification level.
#'
#' @param class_level Classification level: "HIGH", "LOW", or "LAYOUT"
#' @return Character vector of function names
#' @keywords internal
get_functions_by_class <- function(class_level) {
  if (class_level %in% names(.base_r_function_classes)) {
    return(.base_r_function_classes[[class_level]])
  }
  character(0)
}

#' Check if Function is HIGH-level
#'
#' @param function_name Name of the function
#' @return TRUE if HIGH-level, FALSE otherwise
#' @keywords internal
is_high_level_function <- function(function_name) {
  classify_function(function_name) == "HIGH"
}

#' Check if Function is LOW-level
#'
#' @param function_name Name of the function
#' @return TRUE if LOW-level, FALSE otherwise
#' @keywords internal
is_low_level_function <- function(function_name) {
  classify_function(function_name) == "LOW"
}

#' Check if Function is LAYOUT-level
#'
#' @param function_name Name of the function
#' @return TRUE if LAYOUT-level, FALSE otherwise
#' @keywords internal
is_layout_function <- function(function_name) {
  classify_function(function_name) == "LAYOUT"
}

#' Get All Patchable Functions
#'
#' Returns a list of all functions that should be patched, organized by class.
#'
#' @return List with HIGH, LOW, and LAYOUT function vectors
#' @keywords internal
get_all_patchable_functions <- function() {
  .base_r_function_classes
}

#' Get Flat List of All Patchable Functions
#'
#' Returns a flat vector of all functions to patch.
#'
#' @return Character vector of all patchable function names
#' @keywords internal
get_all_function_names <- function() {
  unlist(.base_r_function_classes, use.names = FALSE)
}

