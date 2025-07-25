#' Extract selector for SVG elements (S3 generic)
#' @export
extract_selector <- function(svg, type, ...) {
  UseMethod("extract_selector", type)
}

#' Default method for extract_selector
#' @export
extract_selector.default <- function(svg, type, ...) {
  stop("No selector logic implemented for this plot type.")
}

#' Bar plot selector method (returns selector string for bar rects with maidr id)
#' @export
extract_selector.bar <- function(svg, type, layer_id, ...) {
  paste0("g[clip-path] > rect[maidr='", layer_id, "']")
} 