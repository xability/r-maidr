#' Base R Heatmap Layer Processor
#'
#' Processes Base R heatmap layers using the heatmap() function
#'
#' @keywords internal
BaseRHeatmapLayerProcessor <- R6::R6Class(
  "BaseRHeatmapLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL,
      layer_info = NULL
    ) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "heat",
        title = title,
        axes = axes,
        dom_mapping = list(order = "row") # Explicit row-major DOM mapping
      )
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract matrix data (first unnamed argument for heatmap())
      heat_matrix <- NULL
      if (length(args) > 0 && length(names(args)) > 0 && names(args)[1] == "") {
        heat_matrix <- args[[1]]
      }

      if (is.null(heat_matrix) || !is.matrix(heat_matrix)) {
        return(list(points = list(), x = character(0), y = character(0)))
      }

      # Get row and column names
      row_names <- rownames(heat_matrix)
      col_names <- colnames(heat_matrix)

      if (is.null(row_names)) {
        row_names <- as.character(seq_len(nrow(heat_matrix)))
      }
      if (is.null(col_names)) {
        col_names <- as.character(seq_len(ncol(heat_matrix)))
      }

      # Convert matrix to points format
      # points is a 2D array where points[row][col] = value
      # IMPORTANT: Base R heatmap() renders rows from bottom to top visually
      # but DOM elements are created in row-major order matching visual layout
      # We need to reverse to match the visual bottom-to-top order
      points <- list()
      for (i in seq_len(nrow(heat_matrix))) {
        row_values <- list()
        for (j in seq_len(ncol(heat_matrix))) {
          row_values[[j]] <- heat_matrix[i, j]
        }
        points[[i]] <- row_values
      }

      # Reverse to match visual bottom-to-top order
      points_reversed <- rev(points)
      row_names_reversed <- rev(row_names)

      list(
        points = points_reversed,
        x = as.list(col_names),
        y = as.list(row_names_reversed)
      )
    },
    generate_selectors = function(layer_info, gt = NULL) {
      if (is.null(gt)) {
        return(list())
      }

      # Use group_index for grob lookup
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Search for image-rect grobs (heatmap creates image-rect patterns)
      selector <- self$generate_selectors_from_grob(gt, group_index)

      if (length(selector) > 0 && selector != "") {
        return(list(selector))
      }

      # Fallback selector
      main_selector <- paste0(
        "g#graphics-plot-",
        group_index,
        "-image-rect-1\\.1 > rect"
      )
      list(main_selector)
    },
    find_image_rect_grobs = function(grob, group_index) {
      names <- character(0)

      # Look for graphics-plot pattern matching image-rect
      if (!is.null(grob$name)) {
        pattern <- paste0("graphics-plot-", group_index, "-image-rect-1")
        if (grepl(pattern, grob$name)) {
          names <- c(names, grob$name)
        }
      }

      # Recursively search through gList
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_image_rect_grobs(grob[[i]], group_index))
        }
      }

      # Recursively search through gTree children
      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(
              names,
              self$find_image_rect_grobs(grob$children[[i]], group_index)
            )
          }
        }
      }

      # Also check grobs field
      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_image_rect_grobs(grob$grobs[[i]], group_index))
        }
      }

      names
    },
    generate_selectors_from_grob = function(grob, group_index = NULL) {
      # Find image-rect grobs recursively
      rect_names <- self$find_image_rect_grobs(grob, group_index)

      if (length(rect_names) == 0) {
        return("")
      }

      # Take first matching grob name
      name <- rect_names[1]
      svg_id <- paste0(name, ".1")
      escaped <- gsub("\\.", "\\\\.", svg_id)
      selector <- paste0("g#", escaped, " > rect")

      selector
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = "", fill = ""))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract axis titles from plot call arguments
      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""
      # For heatmaps, fill represents the data values
      # Use a reasonable default label for the color scale
      fill_title <- "value"

      list(x = x_title, y = y_title, fill = fill_title)
    },
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract main title from plot call arguments
      main_title <- if (!is.null(args$main)) args$main else ""

      main_title
    }
  )
)
