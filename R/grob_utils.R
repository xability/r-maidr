# Utility functions for grob manipulation

#' Does a layer's curve land in the panel's auto-named polyline population?
#'
#' `layer_polyline_grobs()` keeps every polyline that no *geom-named* tree
#' claims, so the population it returns is "layers that draw a BARE polyline"
#' -- which is not the same set as "layers typed line". `geom_function()` is
#' typed `smooth` and draws one anyway: `GeomFunction` inherits
#' `GeomPath$draw_panel()`, which returns a `polylineGrob` with nothing named
#' around it, while `GeomSmooth` and `GeomDensity` wrap theirs in
#' `geom_smooth.gTree` / `geom_density.gTree` and are skipped whole.
#'
#' Counting only the line-ish types therefore counted a population one
#' smaller than the one being indexed, and a `geom_function()` drawn *before*
#' a `geom_line()` handed the line the function's curve to highlight (#204).
#' Both charts read correctly the whole time, which is the highlight-only
#' shape xability/maidr#814 names.
#'
#' @param layer A ggplot2 layer.
#' @param type The layer type the adapter detected for it.
#' @return `TRUE` when the layer draws a bare, auto-named polyline.
#' @keywords internal
layer_draws_bare_polyline <- function(layer, type) {
  if (isTRUE(type %in% c("line", "step", "contour"))) {
    return(TRUE)
  }
  isTRUE(inherits(layer$geom, "GeomFunction"))
}

#' Position (1-based) of a layer among the polyline-producing layers of a plot
#'
#' `layer_polyline_grobs()` returns every polyline in the panel that no
#' geom-named grob tree claims, so the index used to pick one out has to be
#' counted over the same population.
#' `geom_line()` / `geom_path()` / `tidyquant::geom_ma()` (detected as
#' `"line"`), `geom_step()` (detected as `"step"`) and `geom_contour()` /
#' `geom_density_2d()` (detected as `"contour"`) each render one auto-named
#' polyline grob per layer, so all three types count. Counting only `"line"`
#' layers would index the wrong polyline for *every* layer of a plot that
#' combines them -- and both charts would read correctly while outlining each
#' other's curves, which is the highlight-only failure xability/maidr#814
#' names.
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
        if (layer_draws_bare_polyline(plot$layers[[i]], tp)) {
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
