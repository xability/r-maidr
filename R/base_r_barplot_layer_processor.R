#' Base R Bar Plot Layer Processor
#'
#' Processes Base R bar plot layers based on recorded plot calls
#'
#' @keywords internal
BaseRBarplotLayerProcessor <- R6::R6Class(
  "BaseRBarplotLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       scale_mapping = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      data <- self$extract_data(layer_info)
      selectors <- self$generate_selectors(layer_info, gt)
      axes <- self$extract_axis_titles(layer_info)
      title <- self$extract_main_title(layer_info)

      list(
        data = data,
        selectors = selectors,
        type = "bar",
        title = title,
        axes = axes
      )
    },
    needs_reordering = function() {
      FALSE # Base R bar plots don't need reordering like ggplot2
    },
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Elegant extraction: Get height (primary argument)
      height <- args$height
      if (is.null(height) && length(args) > 0) {
        height <- args[[1]] # First argument if height not named
      }

      labels <- args$names.arg
      if (is.null(labels)) {
        labels <- names(height)
      }
      if (is.null(labels)) {
        labels <- seq_along(height)
      }

      data_points <- list()

      if (!is.null(height)) {
        # Simple vector case - most common for simple barplots
        height <- as.numeric(height)
        labels <- as.character(labels)

        # Ensure same length
        n <- min(length(height), length(labels))

        data_df <- data.frame(
          x = labels[1:n],
          y = height[1:n],
          stringsAsFactors = FALSE
        )

        sorted_indices <- order(data_df$x)
        data_df <- data_df[sorted_indices, ]

        for (i in seq_len(nrow(data_df))) {
          data_points[[i]] <- list(
            x = data_df$x[i],
            y = data_df$y[i]
          )
        }
      }

      data_points
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
    },
    generate_selectors = function(layer_info, gt = NULL) {
      # For Base R plots converted with ggplotify, we generate selectors
      # using the same recursive approach as ggplot2
      # We search through the grob tree to find rect grobs

      selectors <- list()

      # For multipanel plots, use group_index (panel number)
      # For single panel, use the regular index
      selector_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Use recursive search through the grob tree (definitive approach)
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, selector_index)
      }

      selectors
    },

    #' @description Recursively find rect grobs in the grob tree (like ggplot2 does)
    #' @param grob The grob tree to search
    #' @param call_index The plot call index to match
    #' @return Character vector of grob names
    find_rect_grobs = function(grob, call_index) {
      names <- character(0)

      if (
        !is.null(grob$name) && grepl(paste0("graphics-plot-", call_index, "-rect-1"), grob$name)
      ) {
        names <- c(names, grob$name)
      }

      # Recursively search children (same logic as ggplot2)
      if (inherits(grob, "gList")) {
        for (i in seq_along(grob)) {
          names <- c(names, self$find_rect_grobs(grob[[i]], call_index))
        }
      }

      if (inherits(grob, "gTree")) {
        if (!is.null(grob$children)) {
          for (i in seq_along(grob$children)) {
            names <- c(names, self$find_rect_grobs(grob$children[[i]], call_index))
          }
        }
      }

      names
    },

    #' @description Generate selectors from grob tree (like ggplot2 does)
    #' @param grob The grob tree to search
    #' @param call_index The plot call index
    #' @return List of selectors
    generate_selectors_from_grob = function(grob, call_index) {
      rect_names <- self$find_rect_grobs(grob, call_index)

      if (length(rect_names) == 0) {
        return(list())
      }

      selectors <- lapply(rect_names, function(name) {
        svg_id <- paste0(name, ".1")
        escaped <- gsub("\\.", "\\\\.", svg_id)
        selector <- paste0("#", escaped, " rect")
        selector
      })

      selectors
    }
  )
)
