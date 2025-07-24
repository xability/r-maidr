#' Extract data from bar plots
#'
#' @param layer ggplot2 layer object
#' @param plot_data ggplot_build output
#' @param layer_index index of the layer
#' @return list with extracted data and metadata
#' @export
extract_bar_data <- function(layer, plot_data, layer_index) {
  # Get the layer data from ggplot_build
  layer_data <- plot_data$data[[layer_index]]

  # Extract x and y values
  y_values <- layer_data$y

  # Handle factor levels for categorical x-axis
  x_names <- extract_bar_x_labels(layer_data, plot_data)

  # Create data frame
  plot_df <- data.frame(
    x = x_names,
    y = y_values,
    stringsAsFactors = FALSE
  )

  # Return structured data
  list(
    type = "bar",
    data = plot_df,
    selector = "rect",
    metadata = list(
      x_label = plot_data$plot$labels$x %||% "",
      y_label = plot_data$plot$labels$y %||% "",
      title = plot_data$plot$labels$title %||% ""
    )
  )
}

#' Helper: Extract bar plot x-axis labels
#'
#' @param layer_data layer data from ggplot_build
#' @param plot_data full plot data from ggplot_build
#' @return character vector of x-axis labels
extract_bar_x_labels <- function(layer_data, plot_data) {
  x_values <- layer_data$x

  if (is.numeric(x_values)) {
    # Get the original data to extract factor levels
    original_data <- plot_data$plot$data
    if (!is.null(original_data)) {
      # Try to get the x variable name from the plot mapping
      x_var <- rlang::as_name(plot_data$plot$mapping$x)
      if (length(x_var) == 1 && x_var %in% names(original_data)) {
        # Get factor levels
        factor_levels <- levels(original_data[[x_var]])
        if (!is.null(factor_levels)) {
          return(factor_levels[x_values])
        }
      }
    }
    # Fallback to character conversion
    return(as.character(x_values))
  } else {
    return(as.character(x_values))
  }
}

#' Wrap bar rectangles based on data point count
#'
#' This is a robust approach that counts the number of data points
#' and wraps the corresponding number of rects in a group.
#'
#' @param svg_content character vector of SVG lines
#' @param data_points number of data points (bars) to expect
#' @return modified SVG content with bar rects wrapped in a group
#' @export
wrap_bar_rects_by_count <- function(svg_content, data_points) {
  if (is.null(data_points) || is.na(data_points) || !is.numeric(data_points) || data_points < 1) {
    return(svg_content)
  }

  plot_area_pattern <- "<g clip-path='url\\(#[^']*\\)'>"
  plot_area_starts <- grep(plot_area_pattern, svg_content)
  plot_area_ends <- which(svg_content == "</g>")

  # If no plot area groups, return original
  if (length(plot_area_starts) == 0) {
    return(svg_content)
  }

  # Loop through all plot area groups
  for (plot_area_start in plot_area_starts) {
    plot_area_end <- plot_area_ends[plot_area_ends > plot_area_start][1]
    if (is.na(plot_area_end)) next

    plot_area_content <- svg_content[plot_area_start:plot_area_end]
    rect_lines <- grep("<rect", plot_area_content)

    # Need at least background + bars
    if (length(rect_lines) < (data_points + 1)) next

    # Skip first rect (background) and take next data_points rects as bars
    bar_rect_lines <- rect_lines[2:(data_points + 1)]

    # Validate we have the right number of bar rects
    if (length(bar_rect_lines) != data_points) next

    # Build the new plot area content
    new_plot_area <- plot_area_content[1]

    # Add content before the first bar rect
    if (bar_rect_lines[1] > 2) {
      for (i in 2:(bar_rect_lines[1] - 1)) {
        new_plot_area <- c(new_plot_area, plot_area_content[i])
      }
    }

    # Add the maidr-bars wrapper
    new_plot_area <- c(new_plot_area, '  <g class="maidr-bars">')

    # Add the bar rects with proper indentation
    for (i in bar_rect_lines) {
      rect_line <- plot_area_content[i]
      rect_line <- sub("^\\s*", "    ", rect_line)
      new_plot_area <- c(new_plot_area, rect_line)
    }

    # Close the maidr-bars wrapper
    new_plot_area <- c(new_plot_area, "  </g>")

    # Add remaining content after the last bar rect
    if (bar_rect_lines[length(bar_rect_lines)] < length(plot_area_content)) {
      for (i in (bar_rect_lines[length(bar_rect_lines)] + 1):length(plot_area_content)) {
        new_plot_area <- c(new_plot_area, plot_area_content[i])
      }
    }

    # Splice the new group into the SVG, replacing the original plot area group
    result <- c(
      svg_content[1:(plot_area_start - 1)],
      new_plot_area,
      svg_content[(plot_area_end + 1):length(svg_content)]
    )
    return(result)
  }

  # If no suitable group found, return original
  return(svg_content)
}

#' Identify bar rectangles using the wrapped group structure
#'
#' @param svg_content character vector of SVG lines
#' @return integer vector of line indices containing bar rectangles
#' @export
identify_bar_rectangles_wrapped <- function(svg_content) {
  # Look for the maidr-bars group
  bars_group_start <- grep('<g class="maidr-bars">', svg_content)

  if (length(bars_group_start) == 0) {
    return(integer(0)) # No wrapped structure found
  }

  # Find the end of the bars group
  bars_group_ends <- which(svg_content == "  </g>")
  bars_group_end <- bars_group_ends[bars_group_ends > bars_group_start[1]][1]

  if (is.na(bars_group_end)) {
    return(integer(0)) # No closing tag found
  }

  # Get all rect elements within the bars group
  bar_rect_indices <- grep("<rect", svg_content[bars_group_start:bars_group_end]) + bars_group_start - 1

  return(bar_rect_indices)
}
