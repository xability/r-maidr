#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' Assembles the maidr data structure for a ggplot2 bar plot.
#' @param plot A ggplot2 object
#' @param ... Additional arguments (unused for now)
#' @return A list representing the maidr data structure
#' @export
maidr <- function(plot, ...) {
  if (!inherits(plot, "ggplot")) {
    stop("Input must be a ggplot object.")
  }
  # Detect plot type
  plot_type <- get_plot_type(plot)
  if (plot_type != "bar") {
    stop("Currently only bar plots are supported.")
  }
  # Extract layout
  layout <- extract_layout(plot)
  # Build the plot (to get computed data)
  built <- ggplot2::ggplot_build(plot)
  # Extract all layers (modular, extensible)
  layers <- extract_layers(plot, built, layout)
  # Assemble the maidr structure (single subplot, single layer for now)
  maidr_obj <- list(
    id = "maidr-plot-1",
    subplots = list(
      list(
        id = "maidr-subplot-1",
        layers = layers
      )
    )
  )
  return(maidr_obj)
}

#' Extract all traces/layers from a ggplot2 plot
#' @keywords internal
extract_layers <- function(plot, built, layout) {
  layers <- list()
  for (i in seq_along(plot$layers)) {
    layer <- plot$layers[[i]]
    geom_class <- class(layer$geom)[1]
    # Only bar layers for now, but easily extensible
    if (geom_class %in% c("GeomBar", "GeomCol")) {
      trace <- extract_trace(layer, built$data[[i]], layout = layout, layer_id = paste0("maidr-layer-", i))
      layers[[length(layers) + 1]] <- trace
    }
    # Add more geom types here in the future
  }
  layers
}

#' Save a plot as a standalone HTML file with accessibility and dependencies
#' @param plot A ggplot2 object
#' @param file Output HTML file name
#' @export
save_html <- function(plot, file, ...) {
  stopifnot(inherits(plot, "ggplot"))
  # Build the plot and extract layout
  built <- ggplot2::ggplot_build(plot)
  layout <- extract_layout(plot)
  # Generate unique layer_id for each layer
  layers <- list()
  layer_ids <- character(length(plot$layers))
  for (i in seq_along(plot$layers)) {
    layer_id <- paste0("layer-", as.integer(Sys.time()), "-", i)
    layer_ids[i] <- layer_id
    layer <- plot$layers[[i]]
    geom_class <- class(layer$geom)[1]
    if (geom_class %in% c("GeomBar", "GeomCol")) {
      trace <- extract_trace(layer, built$data[[i]], layout = layout, layer_id = layer_id)
      # Update selector to use the real layer_id
      trace$selectors <- paste0("g[clip-path] > rect[maidr='", layer_id, "']")
      layers[[length(layers) + 1]] <- trace
    }
  }
  # Assemble maidr-data structure
  maidr_data <- list(
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
  # Save SVG
  svg_file <- tempfile(fileext = ".svg")
  ggplot2::ggsave(svg_file, plot = plot, width = 6, height = 4, device = "svg")
  # Annotate SVG with maidr attribute for each bar layer
  for (i in seq_along(layer_ids)) {
    add_maidr_id_to_bars(svg_file, svg_file, layer_ids[i])
  }
  # Inject maidr-data attribute
  library(xml2)
  doc <- read_xml(svg_file)
  library(jsonlite)
  doc <- inject_maidr_data_attribute(doc, toJSON(maidr_data, auto_unbox = TRUE))
  # Save modified SVG as string
  svg_content <- as.character(doc)
  # Wrap in HTML and attach dependencies
  library(htmltools)
  html_doc <- tags$html(
    tags$head(),
    tags$body(
      HTML(svg_content)
    )
  )
  html_doc <- attachDependencies(html_doc, maidr_html_dependencies())
  htmltools::save_html(html_doc, file = file)
  invisible(file)
}

#' Display a plot in the appropriate environment (browser, Viewer, etc.)
#' @param plot A ggplot2 object
#' @export
maidr <- function(plot, ...) {
  file <- tempfile(fileext = ".html")
  save_html(plot, file, ...)
  # Open in RStudio Viewer or browser
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(htmltools::includeHTML(file))
  } else {
    utils::browseURL(file)
  }
  invisible(file)
} 