#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' @param plot A ggplot2 object
#' @param file Optional file path to save HTML. If NULL, creates temporary file
#' @param open Whether to open the HTML file in browser/RStudio Viewer
#' @param ... Additional arguments passed to internal functions
#' @export
maidr <- function(plot, file = NULL, open = TRUE, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }

  html_doc <- create_maidr_html(plot, ...)

  if (is.null(file)) {
    if (open) display_html(html_doc)
    result <- NULL
  } else {
    save_html_document(html_doc, file)
    if (open) display_html_file(file)
    result <- file
  }

  invisible(result)
}

#' Create HTML document with maidr enhancements using the orchestrator
#' @param plot A ggplot2 object
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object
#' @keywords internal
create_maidr_html <- function(plot, ...) {
  orchestrator <- PlotOrchestrator$new(plot)

  gt <- orchestrator$get_gtable()

  layout <- orchestrator$get_layout()

  layers <- create_layers_from_orchestrator(orchestrator, layout)

  maidr_data <- create_maidr_data(layers)
  svg_content <- create_enhanced_svg(gt, maidr_data, ...)
  html_doc <- create_html_document(svg_content)

  html_doc
}

#' Create layers structure from orchestrator data
#' @param orchestrator The PlotOrchestrator instance
#' @param layout Layout information
#' @return List of layer structures
#' @keywords internal
create_layers_from_orchestrator <- function(orchestrator, layout) {
  layers <- list()
  layer_processors <- orchestrator$get_layer_processors()

  for (i in seq_along(layer_processors)) {
    processor <- layer_processors[[i]]
    layer_info <- processor$layer_info

    processed_result <- processor$get_last_result()

    if (!is.null(processed_result)) {
      selectors <- processed_result$selectors
      data <- processed_result$data
      axes <- processed_result$axes

      # Include orientation and type from processor if available
      orientation <- if (!is.null(processed_result$orientation)) processed_result$orientation else "vert"
    } else {
      selectors <- list()
      data <- list()
      axes <- list(x = "", y = "")
      orientation <- ""
      type <- layer_info$type
    }

    layer_obj <- list(
      id = layer_info$index,
      selectors = selectors,
      type = layer_info$type,
      data = data,
      title = if (!is.null(layout$title)) layout$title else "",
      axes = axes
    )

    # Only include orientation if it's not the default "vert"
    if (orientation != "") {
      layer_obj$orientation <- orientation
    }

    layers[[i]] <- layer_obj
  }

  layers
}



#' Create maidr-data structure
#' @param layers List of plot layers
#' @return List containing maidr-data structure
#' @keywords internal
create_maidr_data <- function(layers) {
  list(
    id = paste0("maidr-plot-", as.integer(Sys.time())),
    subplots = list(
      list(
        list(
          id = paste0("maidr-subplot-", as.integer(Sys.time())),
          layers = layers
        )
      )
    )
  )
}
