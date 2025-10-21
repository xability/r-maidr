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
      hist_obj <- hist(hist_data, plot = FALSE)
      
      breaks <- hist_obj$breaks
      counts <- hist_obj$counts
      mids <- hist_obj$mids
      
      # Convert to MAIDR format (same as ggplot2 histogram format)
      histogram_data <- list()
      for(i in 1:length(counts)) {
        histogram_data[[i]] <- list(
          x = mids[i],           # Center of bin
          y = counts[i],          # Frequency count
          xMin = breaks[i],      # Left edge
          xMax = breaks[i+1],    # Right edge
          yMin = 0,              # Always 0
          yMax = counts[i]       # Same as y
        )
      }
      
      return(histogram_data)
    },
    
    generate_selectors = function(layer_info, gt = NULL) {
      plot_call_index <- layer_info$index

      # Use the working method - generate selectors from the provided grob
      if (!is.null(gt)) {
        selectors <- self$generate_selectors_from_grob(gt, plot_call_index)
        if (length(selectors) > 0 && selectors != "") {
          # Return as array with the first (most specific) selector
          return(list(selectors))
        }
      }

      # Fallback selector for histograms - return as array
      main_selector <- paste0("rect[id^='graphics-plot-", plot_call_index, "-rect-1']")
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
    
    generate_selectors_from_grob = function(grob, call_index) {
      rect_names <- self$find_rect_grobs(grob, call_index)

      if (length(rect_names) == 0) {
        return("")
      }

      # Use the main container pattern - this is the working method
      main_container_pattern <- paste0("graphics-plot-", call_index, "-rect-1")
      main_containers <- rect_names[grepl(main_container_pattern, rect_names)]

      if (length(main_containers) > 0) {
        # Find the container with .1 suffix (the parent container)
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
