#' Base R Histogram Layer Processor
#'
#' Processes Base R histogram plot layers using verified data extraction
#' and selector generation logic.
#'
#' @keywords internal
BaseRHistogramLayerProcessor <- R6::R6Class("BaseRHistogramLayerProcessor",
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
        type = "hist",
        title = title,
        axes = axes
      )
    },
    
    extract_data = function(layer_info) {
      if (is.null(layer_info)) {
        return(list())
      }

      # Get the histogram call arguments
      plot_call <- layer_info$plot_call
      args <- plot_call$args
      
      # Extract the data (first argument)
      hist_data <- args[[1]]
      
      # Create histogram object to get breaks, counts, mids
      # Pass the original parameters to ensure same binning as the plot
      # Suppress warnings about unused probability parameter
      hist_params <- list(plot = FALSE)
      if (!is.null(args$breaks)) hist_params$breaks <- args$breaks
      if (!is.null(args$probability)) hist_params$probability <- args$probability
      
      hist_obj <- suppressWarnings(do.call(hist, c(list(hist_data), hist_params)))
      
      breaks <- hist_obj$breaks
      counts <- hist_obj$counts
      mids <- hist_obj$mids
      
      # Convert to MAIDR format (same as ggplot2 histogram format)
      histogram_data <- list()
      for (i in seq_along(counts)) {
        histogram_data[[i]] <- list(
          x = mids[i],
          y = counts[i],
          xMin = breaks[i],
          xMax = breaks[i + 1],
          yMin = 0,
          yMax = counts[i]
        )
      }

      return(histogram_data)
    },
    
    generate_selectors = function(layer_info, gt = NULL) {
      # Use group_index for grob lookup (not layer index)
      # Multiple layers in same group share same grob with group-based naming
      group_index <- if (!is.null(layer_info$group_index)) {
        layer_info$group_index
      } else {
        layer_info$index
      }

      # Use the working method - generate selectors from the provided grob
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, group_index)
        if (length(selectors) > 0 && selectors != "") {
          return(list(selectors))
        }
      }

      # Fallback selector for histograms - return as array
      main_selector <- paste0("rect[id^='graphics-plot-", group_index,
                              "-rect-1']")
      list(main_selector)
    },
    
    find_rect_grobs = function(grob, call_index) {
      names <- character(0)

      # Look for graphics-plot pattern matching our call index
      if (!is.null(grob$name) && grepl(paste0("graphics-plot-", call_index, "-rect-1"), grob$name)) {
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
      
      # Also check grobs field (like stacked bar processor)
      if (!is.null(grob$grobs)) {
        for (i in seq_along(grob$grobs)) {
          names <- c(names, self$find_rect_grobs(grob$grobs[[i]], call_index))
        }
      }

      names
    },
    
    generate_selectors_from_grob = function(grob, call_index = NULL) {
      # Use robust selector generation with plot_index for multipanel support
      selector <- generate_robust_selector(grob, "rect", "rect", plot_index = call_index)
      
      return(selector)
    },
    
    extract_axis_titles = function(layer_info) {
      if (is.null(layer_info)) {
        return(list(x = "", y = ""))
      }

      plot_call <- layer_info$plot_call
      args <- plot_call$args

      # Extract axis titles from plot call arguments
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

      # Extract main title from plot call arguments
      main_title <- if (!is.null(args$main)) args$main else ""

      main_title
    }
  )
)
