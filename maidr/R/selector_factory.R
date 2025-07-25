#' Factory for creating selector functions
#' @export
make_selector <- function(type = "bar", ...) {
  function(svg, ...) {
    extract_selector(svg, type = type, ...)
  }
} 