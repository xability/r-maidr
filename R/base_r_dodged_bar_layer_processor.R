#' Base R Dodged Bar Layer Processor
#'
#' Processes Base R dodged bar plot layers with proper ordering to match backend logic
#'
#' @keywords internal
BaseRDodgedBarLayerProcessor <- R6::R6Class(
  "BaseRDodgedBarLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot, layout, built = NULL, gt = NULL, layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "dodged_bar",
        title = title,
        axes = axes,
        domMapping = list(groupDirection = "forward")
      )
    },
    extract_data = function(layer_info) {
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      height_matrix <- args[[1]]

      col_names <- args$names.arg
      row_names <- NULL

      # Check legend.text: use it only if it's a character vector, not TRUE/FALSE
      if (!is.null(args$legend.text) && is.character(args$legend.text)) {
        row_names <- args$legend.text
      }

      if (is.null(col_names)) {
        col_names <- colnames(height_matrix)
        if (is.null(col_names)) {
          col_names <- seq_len(ncol(height_matrix))
        }
      }

      if (is.null(row_names)) {
        row_names <- rownames(height_matrix)
      }

      if (is.null(row_names)) {
        row_names <- seq_len(nrow(height_matrix))
      }

      col_names <- as.character(col_names)
      row_names <- as.character(row_names)

      sorted_series_names <- sort(row_names)

      data_by_fill <- list()

      for (i in seq_len(length(sorted_series_names))) {
        series_name <- sorted_series_names[i]
        original_index <- which(row_names == series_name)
        series_data <- list()

        sorted_category_names <- sort(col_names)

        for (j in seq_len(length(sorted_category_names))) {
          category_name <- sorted_category_names[j]
          original_col_index <- which(col_names == category_name)

          series_data[[j]] <- list(
            x = category_name, # x-axis value (category)
            y = height_matrix[original_index, original_col_index], # y-value
            fill = series_name # fill/series value
          )
        }

        data_by_fill[[length(data_by_fill) + 1]] <- series_data
      }

      data_by_fill
    },
    generate_selectors = function(layer_info, gt = NULL) {
      # For multipanel plots, use group_index (panel number)
      # For single panel, use the regular index
      plot_call_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Use the working method - generate selectors from the provided grob
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, plot_call_index)
        if (length(selectors) > 0 && selectors != "") {
          return(list(selectors))
        }
      }

      # Fallback selector for dodged bars - return as array
      main_selector <- paste0("rect[id^='graphics-plot-", plot_call_index, "-rect-1']")
      list(main_selector)
    },
    find_rect_grobs = function(grob, call_index) {
      names <- character(0)

      # Look for graphics-plot pattern matching our call index
      if (
        !is.null(grob$name) && grepl(paste0("graphics-plot-", call_index, "-rect-1"), grob$name)
      ) {
        names <- c(names, grob$name)
      }

      # Recursively search through gList
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_rect_grobs(grob[[i]], call_index))
        }
      }

      # Recursively search through gTree children
      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names, self$find_rect_grobs(grob$children[[i]], call_index))
          }
        }
      }

      names
    },
    generate_selectors_from_grob = function(grob, call_index) {
      rect_names <- self$find_rect_grobs(grob, call_index)

      if (length(rect_names) == 0) {
        return("")
      }

      # Use the main container pattern - this is the working method
      main_container_pattern <- paste0("graphics-plot-", call_index, "-rect-1")
      main_containers <- rect_names[grepl(main_container_pattern, rect_names)]

      if (length(main_containers) > 0) {
        parent_containers <- main_containers[grepl("\\.1$", main_containers)]
        if (length(parent_containers) > 0) {
          escaped_parent <- gsub("\\.", "\\\\.", parent_containers[1])
          return(paste0("#", escaped_parent, " rect"))
        }
      }

      # Fallback to pattern-based selector
      paste0("rect[id^='graphics-plot-", call_index, "-rect-1']")
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""

      list(x = x_title, y = y_title)
    },
    extract_main_title = function(layer_info) {
      if (is.null(layer_info)) {
        return("")
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      main_title <- if (!is.null(args$main)) args$main else ""

      main_title
    }
  )
)
