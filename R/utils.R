#' Utility functions for r-maidr package

#' Generate unique ID for plot elements
#' 
#' @param prefix character prefix for the ID
#' @return character unique ID
#' @export
generate_id <- function(prefix = "element") {
  paste0(prefix, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
}

#' Safe null coalescing operator
#' 
#' @param x value to check
#' @param y fallback value
#' @return x if not null, otherwise y
#' @export
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Convert data frame to MAIDR data format
#' 
#' @param df data frame with x and y columns
#' @return list of data points in MAIDR format
#' @export
df_to_maidr_data <- function(df) {
  lapply(1:nrow(df), function(i) {
    list(
      x = as.character(df$x[i]),
      y = as.numeric(df$y[i])
    )
  })
}

#' Get SVG selector for plot type
#' 
#' @param plot_type character plot type
#' @return character SVG selector
#' @export
get_svg_selector <- function(plot_type) {
  switch(plot_type,
         bar = "rect",
         "rect")
}

#' Extract plot metadata from ggplot object
#' 
#' @param plot_obj ggplot2 plot object
#' @return list with title, x_label, y_label
#' @export
extract_plot_metadata <- function(plot_obj) {
  list(
    title = plot_obj$labels$title %||% "",
    x_label = plot_obj$labels$x %||% "",
    y_label = plot_obj$labels$y %||% ""
  )
}

#' Determine plot type from geom class
#' 
#' @param geom_class character geom class name
#' @return character plot type
#' @export
geom_class_to_plot_type <- function(geom_class) {
  if (grepl("bar|col", geom_class, ignore.case = TRUE)) {
    return("bar")
  }
  return("unknown")
} 