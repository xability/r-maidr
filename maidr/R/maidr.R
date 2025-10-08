#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' @param plot A ggplot2 object
#' @param file Optional file path to save HTML. If NULL, creates temporary file
#' @param open Whether to open the HTML file in browser/RStudio Viewer
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param as_widget If TRUE, returns an htmlwidget object instead of opening in browser
#' @param ... Additional arguments passed to internal functions
#' @export
show <- function(plot, file = NULL, open = TRUE, shiny = FALSE, as_widget = FALSE, ...) {
  if (as_widget) {
    return(maidr_widget(plot, ...))
  }

  # Shiny mode - return just the SVG content
  if (shiny) {
    return(create_maidr_html(plot, shiny = TRUE, ...))
  }

  # Default behavior - create full HTML document
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
#' @param shiny If TRUE, returns just the SVG content instead of full HTML document
#' @param ... Additional arguments passed to internal functions
#' @return An htmltools HTML document object or SVG content
#' @keywords internal
create_maidr_html <- function(plot, shiny = FALSE, ...) {
  registry <- get_global_registry()

  system_name <- registry$detect_system(plot)

  adapter <- registry$get_adapter(system_name)

  orchestrator <- adapter$create_orchestrator(plot)

  gt <- orchestrator$get_gtable()

  layout <- orchestrator$get_layout()

  if (orchestrator$is_patchwork_plot() || orchestrator$is_faceted_plot()) {
    maidr_data <- create_maidr_data(layers = NULL, orchestrator = orchestrator)
  } else {
    layers <- create_layers_from_orchestrator(orchestrator, layout)
    maidr_data <- create_maidr_data(layers)
  }

  svg_content <- create_enhanced_svg(gt, maidr_data, ...)

  if (shiny) {
    return(htmltools::HTML(paste(svg_content, collapse = "\n")))
  }

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

    if (orientation != "") {
      layer_obj$orientation <- orientation
    }

    layers[[i]] <- layer_obj
  }

  layers
}



#' Create maidr-data structure
#' @param layers List of plot layers (for single plots) or orchestrator (for faceted plots)
#' @param orchestrator Optional orchestrator instance for faceted plots
#' @return List containing maidr-data structure
#' @keywords internal
create_maidr_data <- function(layers, orchestrator = NULL) {
  # If orchestrator is provided, use it to generate the data structure
  if (!is.null(orchestrator)) {
    return(orchestrator$generate_maidr_data())
  }

  # For single plots, use the original structure
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
