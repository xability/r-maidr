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

      result <- list(
        data = data,
        selectors = selectors,
        type = "bar",
        title = title,
        axes = axes
      )

      # barplot(horiz = TRUE): announce the value axis correctly and let
      # the frontend swap navigation axes
      if (self$is_horizontal(layer_info)) {
        result$orientation <- "horz"
      }

      result
    },

    #' @description Check whether this barplot call used horiz = TRUE
    #' @param layer_info Layer information
    #' @return Logical
    is_horizontal = function(layer_info) {
      if (is.null(layer_info)) {
        return(FALSE)
      }
      isTRUE(layer_info$plot_call$args[["horiz"]])
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

        # Emit data in recorded-call order: the SVG is replayed from the
        # recorded args, so its rects appear in exactly this order. Any
        # re-sorting here (e.g. alphabetical) would misalign announced
        # values and highlights with the drawn bars. (Named inputs are
        # already sorted by the barplot wrapper's SortingPatcher before
        # being recorded.)
        #
        # Horizontal bars swap the point roles: x carries the VALUE and
        # y the category label (the frontend reads values from x when
        # orientation = "horz").
        horizontal <- self$is_horizontal(layer_info)
        for (i in seq_len(n)) {
          data_points[[i]] <- if (horizontal) {
            list(
              x = height[i],
              y = labels[i]
            )
          } else {
            list(
              x = labels[i],
              y = height[i]
            )
          }
        }
      }

      data_points
    },
    # Extract the axis titles for this layer
    #
    # `barplot()` writes no title of its own, so an author who wrote none
    # leaves both axes nameless. A bar chart always plots categories against
    # their measured heights, whether or not the heights arrived named, so
    # that is what the defaults say. `horiz = TRUE` puts the heights on the
    # visual x axis -- the same swap extract_data() applies to the points.
    #
    # @param layer_info Layer information
    # @return Canonical axes list
    extract_axis_titles = function(layer_info) {
      base_r_categorical_axes(
        layer_info$plot_call$args,
        horizontal = self$is_horizontal(layer_info)
      )
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
