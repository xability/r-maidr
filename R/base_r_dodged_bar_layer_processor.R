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

      # Walk the matrix in its recorded order: the SVG is replayed from
      # the recorded (already patch-sorted) args, so re-sorting here would
      # desynchronize data from the drawn rects. This also avoids
      # character-sorting numeric fallback labels ("10" before "2") and
      # mismatches when legend.text order differs from rownames order.
      data_by_fill <- list()

      for (i in seq_len(nrow(height_matrix))) {
        series_data <- list()

        for (j in seq_len(ncol(height_matrix))) {
          series_data[[j]] <- list(
            x = col_names[j], # x-axis value (category)
            y = as.numeric(height_matrix[i, j]), # y-value
            z = row_names[i] # z/series value
          )
        }

        data_by_fill[[i]] <- series_data
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

      # The data rects live in the FIRST rect group (barplot draws the
      # bars before any legend rects). Order candidates by their trailing
      # grob number and take the first; gridSVG appends ".1" to the grob
      # name on export.
      group_numbers <- suppressWarnings(
        as.integer(sub(".*-([0-9]+)$", "\\1", rect_names))
      )
      main_container <- rect_names[order(group_numbers)][1]
      escaped_parent <- gsub("\\.", "\\\\.", paste0(main_container, ".1"))
      paste0("#", escaped_parent, " rect")
    },
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(build_axes(x = "", y = ""))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      x_title <- if (!is.null(args$xlab)) args$xlab else ""
      y_title <- if (!is.null(args$ylab)) args$ylab else ""

      build_axes(x = x_title, y = y_title)
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
