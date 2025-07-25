#' Extract layout information from a ggplot2 object
#' @param gg A ggplot2 object
#' @return A list with layout information: title, axes, facet info
#' @export
extract_layout <- function(gg) {
  if (!inherits(gg, "ggplot")) {
    stop("Input must be a ggplot object.")
  }
  # Title
  title <- gg$labels$title %||% ""
  # Axes labels
  xlab <- gg$labels$x %||% ""
  ylab <- gg$labels$y %||% ""
  # Facet info
  facet_vars <- NULL
  if (!inherits(gg$facet, "FacetNull")) {
    facet_vars <- gg$facet$params$facets
    if (is.null(facet_vars)) facet_vars <- gg$facet$params$rows
    if (is.null(facet_vars)) facet_vars <- gg$facet$params$cols
  }
  list(
    title = title,
    axes = list(x = xlab, y = ylab),
    facet_vars = facet_vars
  )
} 