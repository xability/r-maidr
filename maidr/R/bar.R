#' Bar plot data S3 class
#'
#' This class inherits from plot_data and provides bar-specific functionality.
#'
#' @param data Bar plot data
#' @param layout Layout information
#' @param selectors CSS selectors for bar elements
#' @param ... Additional arguments
#' @return A bar_plot_data object
#' @export
bar_plot_data <- function(data, layout, selectors, ...) {
  # Create base plot_data object
  base_obj <- plot_data(
    type = "bar",
    data = data,
    layout = layout,
    selectors = selectors,
    ...
  )

  # Add bar-specific class
  class(base_obj) <- c("bar_plot_data", class(base_obj))

  base_obj
}

# Note: as.json generic moved to plot_data.R base class

#' Convert bar_plot_data to JSON
#' @param x A bar_plot_data object
#' @param ... Additional arguments passed to jsonlite::toJSON
#' @return JSON string
#' @export
as.json.bar_plot_data <- function(x, ...) {
  jsonlite::toJSON(unclass(x), auto_unbox = TRUE, ...)
}

#' Extract bar plot data
#' @param plot A ggplot2 object
#' @return List of bar plot data points in visual order
#' @export
extract_bar_data <- function(plot) {
  # Build the plot to get data
  built <- ggplot2::ggplot_build(plot)

  # Find bar layers
  bar_layers <- which(sapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")
  }))

  if (length(bar_layers) == 0) {
    stop("No bar layers found in plot")
  }

  # Extract data from first bar layer
  built_data <- built$data[[bar_layers[1]]]
  original_data <- plot$data
  x_col <- NULL
  if (!is.null(original_data) && is.data.frame(original_data)) {
    for (col in names(original_data)) {
      if (is.character(original_data[[col]]) ||
        is.factor(original_data[[col]])) {
        x_col <- col
        break
      }
    }
  }

  # Build data points in original data frame order
  data_points <- list()
  if (nrow(built_data) > 0) {
    for (j in seq_len(nrow(built_data))) {
      point <- list()
      # Add x value (string, for JSON)
      if (!is.null(x_col)) {
        # Get unique values in alphabetical order (ggplot2 default)
        alphabetical_values <- sort(
          unique(as.character(original_data[[x_col]]))
        )
        numeric_index <- built_data$x[j]
        if (numeric_index <= length(alphabetical_values)) {
          point$x <- alphabetical_values[numeric_index]
        } else {
          point$x <- built_data$x[j]
        }
      } else {
        point$x <- built_data$x[j]
      }
      # Add y value
      if ("y" %in% names(built_data)) {
        point$y <- built_data$y[j]
      } else if ("count" %in% names(built_data)) {
        point$y <- built_data$count[j]
      }
      # Add any other relevant data
      if ("fill" %in% names(built_data)) {
        point$fill <- built_data$fill[j]
      }
      data_points[[j]] <- point
    }
  }
  data_points
}

#' Extract bar layer data from plot processor
#' @param plot_processor The plot processor object
#' @param layer_id The layer ID
#' @return Bar layer data structure
#' @keywords internal
extract_bar_layer_data <- function(plot_processor, layer_id) {
  if (is.null(plot_processor$data)) {
    return(list())
  }
  
  # For bar plots, return the data as is
  plot_processor$data
}

#' Make bar plot selector
#' @param layer_id The layer ID
#' @return CSS selector string
#' @keywords internal
make_bar_selector <- function(layer_id) {
  grob_id <- paste0("geom_rect.rect.", layer_id, ".1")
  escaped_grob_id <- gsub("\\.", "\\\\.", grob_id)
  paste0("#", escaped_grob_id, " rect")
}

#' Find bar grobs from a gtable
#' @param gt A gtable object (from ggplotGrob)
#' @return List of bar grobs
#' @keywords internal
find_bar_grobs <- function(gt) {
  panel_index <- which(gt$layout$name == "panel")
  if (length(panel_index) == 0) {
    stop("No panel found in gtable")
  }

  panel_grob <- gt$grobs[[panel_index]]

  if (!inherits(panel_grob, "gTree")) {
    stop("Panel grob is not a gTree")
  }

  find_rect_grobs_recursive <- function(grob) {
    rect_grobs <- list()

    if (inherits(grob, "rectGrob") ||
      (inherits(grob, "rect") && !inherits(grob, "zeroGrob"))) {
      rect_grobs[[length(rect_grobs) + 1]] <- grob
    }

    if (inherits(grob, "gList")) {
      for (i in seq_along(grob)) {
        rect_grobs <- c(rect_grobs, find_rect_grobs_recursive(grob[[i]]))
      }
    }

    if (inherits(grob, "gTree")) {
      for (i in seq_along(grob$children)) {
        rect_grobs <- c(
          rect_grobs,
          find_rect_grobs_recursive(grob$children[[i]])
        )
      }
    }

    rect_grobs
  }

  all_rects <- find_rect_grobs_recursive(panel_grob)

  bar_grobs <- list()
  for (i in seq_along(all_rects)) {
    grob <- all_rects[[i]]
    if (inherits(grob, "rectGrob") || inherits(grob, "rect")) {
      if (!grepl("background|border", grob$name, ignore.case = TRUE)) {
        bar_grobs[[length(bar_grobs) + 1]] <- grob
      }
    }
  }

  bar_grobs
}

#' Make bar plot selectors
#' @param plot A ggplot2 object
#' @return List of CSS selectors for bar elements
#' @keywords internal
make_bar_selectors <- function(plot) {
  # Convert to gtable to get grob information
  gt <- ggplot2::ggplotGrob(plot)

  # Find bar grobs
  grobs <- find_bar_grobs(gt)

  selectors <- list()
  for (grob in grobs) {
    grob_name <- grob$name
    # Extract the numeric part from grob name
    # (e.g., "2" from "geom_rect.rect.2")
    layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)

    # Create selector for this bar
    selector <- make_bar_selector(layer_id)
    selectors[[length(selectors) + 1]] <- selector
  }

  selectors
}
